use anyhow::{Context, Result};
use reqwest::{Client, header};
use serde_json::json;
use urlencoding::encode;

use crate::types::*;

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

        let client = Client::builder()
            .default_headers(headers)
            .timeout(std::time::Duration::from_secs(3))
            .build()?;

        Ok(Self {
            client,
            api_key,
            auth_token,
        })
    }

    fn auth_headers(&self) -> header::HeaderMap {
        let mut headers = header::HeaderMap::new();
        headers.insert(
            "authorization",
            format!(r#"ResyAPI api_key="{}""#, self.api_key).parse().unwrap(),
        );
        headers.insert("x-resy-auth-token", self.auth_token.parse().unwrap());
        headers.insert("x-resy-universal-auth", self.auth_token.parse().unwrap());
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

    pub async fn book(
        &self,
        venue_id: &str,
        party_size: u32,
        day: &str,
        times: &[String],
        types: &[String],
        dry_run: bool,
    ) -> Result<()> {
        println!("📍 Fetching venue details...");
        let venue = self.fetch_venue_details(venue_id).await?;
        println!("🍽️  Restaurant: {}", venue.venue.name);

        println!("\n🔍 Fetching available slots...");
        let slots = self.fetch_slots(venue_id, party_size, day).await?;
        println!("✅ Found {} available slots", slots.len());

        let matching_slots: Vec<_> = slots.iter()
            .filter(|slot| slot.matches(times, types))
            .collect();

        if matching_slots.is_empty() {
            anyhow::bail!("❌ No matching slots found for the specified times/types");
        }

        println!("🎯 Found {} matching slots:", matching_slots.len());
        for slot in &matching_slots {
            println!("   - {} ({})", slot.date.start, slot.config.slot_type);
        }

        if dry_run {
            println!("\n🏃 Dry run mode - skipping actual booking");
            return Ok(());
        }

        println!("\n📝 Attempting to book...");
        for slot in matching_slots {
            println!("   Trying slot: {} ({})", slot.date.start, slot.config.slot_type);
            
            match self.try_book_slot(slot, day, party_size).await {
                Ok(_) => {
                    println!("🎉 Successfully booked reservation!");
                    return Ok(());
                }
                Err(e) => {
                    println!("   ⚠️  Failed: {}", e);
                    continue;
                }
            }
        }

        anyhow::bail!("❌ Could not book any matching slots")
    }

    async fn try_book_slot(&self, slot: &Slot, day: &str, party_size: u32) -> Result<()> {
        let details = self.get_booking_token(&slot.config.token, day, party_size).await?;
        
        let payment_id = details.user.payment_methods
            .as_ref()
            .and_then(|methods| methods.first())
            .map(|method| method.id);

        self.book_reservation(&details.book_token.value, payment_id).await
    }
}

