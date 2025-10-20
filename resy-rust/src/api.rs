use anyhow::{Context, Result};
use reqwest::{Client, header};
use serde_json::json;
use urlencoding::encode;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::time::{Duration, Instant};
use tokio::time::sleep;

use crate::types::*;
use crate::LoggerHandle;

pub struct ResyClient {
    client: Client,
    api_key: String,
    auth_token: String,
}

impl ResyClient {
    pub fn new(api_key: String, auth_token: String) -> Result<Self> {
        let mut headers = header::HeaderMap::new();
        headers.insert(
            "user-agent",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
                .parse()?,
        );
        headers.insert("origin", "https://resy.com".parse()?);
        headers.insert("referrer", "https://resy.com".parse()?);
        headers.insert("x-origin", "https://resy.com".parse()?);
        headers.insert("cache-control", "no-cache".parse()?);

        // Optimize for low latency: connection pooling, TCP optimizations, shorter timeout
        let client = Client::builder()
            .default_headers(headers)
            .pool_max_idle_per_host(10)
            .pool_idle_timeout(Duration::from_secs(90))
            .http1_only()  // Force HTTP/1.1 to avoid HTTP/2 issues with WAF
            .tcp_nodelay(true)
            .timeout(Duration::from_secs(2))
            .connect_timeout(Duration::from_millis(500))
            .build()?;

        Ok(Self {
            client,
            api_key,
            auth_token,
        })
    }

    fn auth_headers(&self) -> header::HeaderMap {
        let mut headers = header::HeaderMap::new();
        let api_key = self.api_key.trim().trim_matches('"').trim_matches('\'');
        let auth_token = self.auth_token.trim().trim_matches('"').trim_matches('\'');
        
        headers.insert(
            "authorization",
            format!(r#"ResyAPI api_key="{}""#, api_key).parse().unwrap(),
        );
        headers.insert("x-resy-auth-token", auth_token.parse().unwrap());
        headers.insert("x-resy-universal-auth", auth_token.parse().unwrap());
        headers
    }

    pub async fn fetch_venue_details(&self, venue_id: &str) -> Result<VenueResponse> {
        let url = format!("https://api.resy.com/2/config?venue_id={}", venue_id);
        let response = self.client
            .get(&url)
            .headers(self.auth_headers())
            .send()
            .await
            .context("Failed to fetch venue details")?;
        
        if !response.status().is_success() {
            anyhow::bail!("Failed to fetch venue details: {}", response.status());
        }
        
        response.json().await.context("Failed to parse venue response")
    }

    pub async fn fetch_slots(
        &self,
        venue_id: &str,
        party_size: u32,
        day: &str,
    ) -> Result<Vec<Slot>> {
        let url = format!(
            "https://api.resy.com/4/find?party_size={}&venue_id={}&day={}&lat=0&long=0",
            party_size, venue_id, day
        );
        
        let response = self.client
            .get(&url)
            .headers(self.auth_headers())
            .send()
            .await
            .context("Failed to fetch slots")?;

        if !response.status().is_success() {
            anyhow::bail!("Failed to fetch slots: {}", response.status());
        }

        let find_response: FindResponse = response.json().await.context("Failed to parse slots response")?;

        if find_response.results.venues.is_empty() {
            anyhow::bail!("No venues found");
        }

        Ok(find_response.results.venues[0].slots.clone())
    }

    pub async fn get_booking_token(
        &self,
        config_id: &str,
        day: &str,
        party_size: u32,
    ) -> Result<DetailsResponse> {
        let url = "https://api.resy.com/3/details";
        let body = BookingConfig {
            config_id: config_id.to_string(),
            day: day.to_string(),
            party_size,
        };

        let response = self.client
            .post(url)
            .headers(self.auth_headers())
            .json(&body)
            .send()
            .await
            .context("Failed to get booking token")?;

        if !response.status().is_success() {
            anyhow::bail!("Failed to get booking token: {}", response.status());
        }

        response.json().await.context("Failed to parse booking details")
    }

    pub async fn book_reservation(&self, book_token: &str, payment_id: Option<u64>) -> Result<()> {
        let url = "https://api.resy.com/3/book";
        let mut form_data = format!("book_token={}", encode(book_token));
        
        if let Some(id) = payment_id {
            let payment_json = json!({"id": id}).to_string();
            form_data.push_str(&format!("&struct_payment_method={}", encode(&payment_json)));
        }

        let response = self.client
            .post(url)
            .headers(self.auth_headers())
            .header("content-type", "application/x-www-form-urlencoded")
            .body(form_data)
            .send()
            .await
            .context("Failed to book reservation")?;

        if !response.status().is_success() {
            anyhow::bail!("Failed to book reservation: {}", response.status());
        }

        Ok(())
    }


    async fn try_book_slot(&self, slot: &Slot, day: &str, party_size: u32) -> Result<()> {
        let details = self.get_booking_token(&slot.config.token, day, party_size).await?;
        
        let payment_id = details.user.payment_methods
            .as_ref()
            .and_then(|methods| methods.first())
            .map(|method| method.id);

        self.book_reservation(&details.book_token.value, payment_id).await
    }

    /// Poll for available slots with configurable interval and timeout
    async fn poll_for_slots(
        &self,
        venue_id: &str,
        party_size: u32,
        day: &str,
        times: &[String],
        types: &[String],
        poll_interval: Duration,
        poll_timeout: Duration,
        logger: &LoggerHandle,
    ) -> Result<Vec<Slot>> {
        let start = Instant::now();
        let mut attempt = 0;

        loop {
            attempt += 1;
            
            // Try to fetch slots
            match self.fetch_slots(venue_id, party_size, day).await {
                Ok(slots) => {
                    let matching: Vec<_> = slots
                        .into_iter()
                        .filter(|slot| slot.matches(times, types))
                        .collect();
                    
                    if !matching.is_empty() {
                        logger.log(&format!("✅ Found {} matching slots after {} attempts ({:.2}s)", 
                            matching.len(), attempt, start.elapsed().as_secs_f64()));
                        return Ok(matching);
                    }
                }
                Err(e) => {
                    // Continue polling even on errors (restaurant might not have released slots yet)
                    if attempt == 1 {
                        logger.log(&format!("⏳ Polling for slots... ({})", e));
                    }
                }
            }

            // Check timeout
            if start.elapsed() >= poll_timeout {
                anyhow::bail!(
                    "❌ No matching slots found after {:.1}s of polling ({} attempts)", 
                    poll_timeout.as_secs_f64(), 
                    attempt
                );
            }

            // Show progress every 5 seconds
            if attempt > 1 && start.elapsed().as_secs() % 5 == 0 && start.elapsed().as_millis() % 1000 < poll_interval.as_millis() {
                logger.log(&format!("⏳ Still polling... ({:.1}s elapsed, {} attempts)", 
                    start.elapsed().as_secs_f64(), attempt));
            }

            sleep(poll_interval).await;
        }
    }

    /// Competitive booking with concurrent threads and retries
    pub async fn book_competitive(
        &self,
        venue_id: &str,
        party_size: u32,
        day: &str,
        times: &[String],
        types: &[String],
        dry_run: bool,
        num_threads: usize,
        num_retries: usize,
        poll_interval: Duration,
        poll_timeout: Duration,
        logger: LoggerHandle,
    ) -> Result<()> {
        logger.log("📍 Fetching venue details...");
        let venue = self.fetch_venue_details(venue_id).await?;
        logger.log(&format!("🍽️  Restaurant: {}", venue.venue.name));

        logger.log("🔍 Polling for available slots...");
        logger.log(&format!("   Poll interval: {}ms", poll_interval.as_millis()));
        logger.log(&format!("   Poll timeout: {}s", poll_timeout.as_secs()));
        
        let matching_slots = self.poll_for_slots(
            venue_id,
            party_size,
            day,
            times,
            types,
            poll_interval,
            poll_timeout,
            &logger,
        ).await?;

        logger.log("🎯 Available matching slots:");
        for slot in &matching_slots {
            logger.log(&format!("   - {} ({})", slot.date.start, slot.config.slot_type));
        }

        if dry_run {
            logger.log("🏃 Dry run mode - skipping actual booking");
            return Ok(());
        }

        // Lock-free coordination using atomics
        let success = Arc::new(AtomicBool::new(false));
        let attempts = Arc::new(AtomicUsize::new(0));
        
        logger.log(&format!("🚀 Launching {} concurrent booking threads...", num_threads));
        
        let mut handles = Vec::new();

        // Spawn multiple concurrent tasks for booking attempts
        for thread_id in 0..num_threads {
            let slot = matching_slots[0].clone(); // Try the first matching slot
            let day = day.to_string();
            let success = Arc::clone(&success);
            let attempts = Arc::clone(&attempts);
            let thread_logger = logger.clone();
            
            // Clone client data for each thread
            let api_key = self.api_key.clone();
            let auth_token = self.auth_token.clone();

            let handle = tokio::spawn(async move {
                // Each thread creates its own client for true concurrency
                let client = match ResyClient::new(api_key, auth_token) {
                    Ok(c) => c,
                    Err(e) => {
                        thread_logger.log(&format!("   Thread {}: Failed to create client: {}", thread_id, e));
                        return;
                    }
                };

                for retry in 0..num_retries {
                    // Check if another thread already succeeded
                    if success.load(Ordering::Relaxed) {
                        return;
                    }

                    attempts.fetch_add(1, Ordering::Relaxed);
                    
                    match client.try_book_slot(&slot, &day, party_size).await {
                        Ok(_) => {
                            // Mark success atomically
                            if !success.swap(true, Ordering::SeqCst) {
                                thread_logger.log(&format!("   ✅ Thread {} succeeded on attempt {}", thread_id, retry + 1));
                            }
                            return;
                        }
                        Err(e) => {
                            if retry == 0 || retry == num_retries - 1 {
                                thread_logger.log(&format!("   ⚠️  Thread {} attempt {}/{}: {}", 
                                    thread_id, retry + 1, num_retries, e));
                            }
                            // Small delay before retry (exponential backoff)
                            if retry < num_retries - 1 {
                                sleep(Duration::from_millis(50 * (retry as u64 + 1))).await;
                            }
                        }
                    }
                }
            });

            handles.push(handle);
        }

        // Wait for all threads to complete
        for handle in handles {
            let _ = handle.await;
        }

        let total_attempts = attempts.load(Ordering::Relaxed);
        
        if success.load(Ordering::Relaxed) {
            logger.log("");
            logger.log("🎉 Successfully booked reservation!");
            logger.log(&format!("   Total attempts: {}", total_attempts));
            Ok(())
        } else {
            anyhow::bail!(
                "❌ Failed to book after {} total attempts across {} threads",
                total_attempts,
                num_threads
            )
        }
    }
}

