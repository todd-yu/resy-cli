mod api;
mod types;

use anyhow::{Context, Result};
use clap::Parser;
use std::env;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use chrono::Local;

use api::ResyClient;

/// Logger that writes to both stdout and a file
pub struct Logger {
    file: Arc<Mutex<std::fs::File>>,
}

impl Logger {
    pub fn new(log_path: PathBuf) -> Result<Self> {
        // Create parent directory if it doesn't exist
        if let Some(parent) = log_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&log_path)
            .context(format!("Failed to open log file: {}", log_path.display()))?;

        Ok(Self {
            file: Arc::new(Mutex::new(file)),
        })
    }

    pub fn log(&self, message: &str) {
        // Print to stdout
        println!("{}", message);
        
        // Write to file with timestamp
        if let Ok(mut file) = self.file.lock() {
            let timestamp = Local::now().format("%Y-%m-%d %H:%M:%S%.3f");
            let _ = writeln!(file, "[{}] {}", timestamp, message);
        }
    }

    pub fn clone_handle(&self) -> LoggerHandle {
        LoggerHandle {
            file: Arc::clone(&self.file),
        }
    }
}

/// A cloneable handle to the logger for use in async tasks
#[derive(Clone)]
pub struct LoggerHandle {
    file: Arc<Mutex<std::fs::File>>,
}

impl LoggerHandle {
    pub fn log(&self, message: &str) {
        println!("{}", message);
        if let Ok(mut file) = self.file.lock() {
            let timestamp = Local::now().format("%Y-%m-%d %H:%M:%S%.3f");
            let _ = writeln!(file, "[{}] {}", timestamp, message);
        }
    }
}

#[derive(Parser, Debug)]
#[command(name = "resy-rust")]
#[command(about = "Book Resy reservations from the command line", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Parser, Debug)]
enum Commands {
    /// Book a reservation
    Book {
        /// Venue ID of the restaurant
        #[arg(long)]
        venue_id: String,

        /// Party size for the reservation
        #[arg(long)]
        party_size: u32,

        /// Reservation date (YYYY-MM-DD)
        #[arg(long)]
        date: String,

        /// Preferred reservation times (HH:MM:SS format, can specify multiple)
        #[arg(long, value_delimiter = ',')]
        times: Vec<String>,

        /// Preferred reservation types (e.g., Indoor, Outdoor, can specify multiple)
        #[arg(long, value_delimiter = ',')]
        types: Option<Vec<String>>,

        /// Dry run mode - fetch slots but don't book
        #[arg(long, default_value = "false")]
        dry_run: bool,

        /// Number of concurrent booking threads (default: 1, recommended: 3-5)
        #[arg(long, default_value = "5")]
        threads: usize,

        /// Number of retry attempts per thread (default: 3)
        #[arg(long, default_value = "5")]
        retries: usize,

        /// Poll interval in milliseconds when waiting for slots (default: 250ms)
        #[arg(long, default_value = "250")]
        poll_interval_ms: u64,

        /// Maximum time to poll for slots in seconds (default: 30s)
        #[arg(long, default_value = "120")]
        poll_timeout_secs: u64,

        /// Log file path (default: ~/.resy-rust/logs/<venue>_<timestamp>.log)
        #[arg(long)]
        log_file: Option<String>,
    },
}

fn get_default_log_path(venue_id: &str) -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    let timestamp = Local::now().format("%Y%m%d_%H%M%S");
    PathBuf::from(home)
        .join(".resy-rust")
        .join("logs")
        .join(format!("venue_{}_{}.log", venue_id, timestamp))
}

#[tokio::main]
async fn main() -> Result<()> {
    dotenv::dotenv().ok();

    let api_key = env::var("RESY_API_KEY")
        .context("RESY_API_KEY not found in environment. Create a .env file with your credentials.")?;
    let auth_token = env::var("RESY_AUTH_TOKEN")
        .context("RESY_AUTH_TOKEN not found in environment. Create a .env file with your credentials.")?;

    let cli = Cli::parse();

    let client = ResyClient::new(api_key, auth_token)?;

    match cli.command {
        Commands::Book {
            venue_id,
            party_size,
            date,
            times,
            types,
            dry_run,
            threads,
            retries,
            poll_interval_ms,
            poll_timeout_secs,
            log_file,
        } => {
            let types = types.unwrap_or_default();
            
            // Set up logging
            let log_path = log_file
                .map(PathBuf::from)
                .unwrap_or_else(|| get_default_log_path(&venue_id));
            
            let logger = Logger::new(log_path.clone())?;
            
            logger.log("═══════════════════════════════════════════════════════");
            logger.log("🚀 Starting Resy booking...");
            logger.log(&format!("   Venue ID: {}", venue_id));
            logger.log(&format!("   Party Size: {}", party_size));
            logger.log(&format!("   Date: {}", date));
            if !times.is_empty() {
                logger.log(&format!("   Times: {}", times.join(", ")));
            }
            if !types.is_empty() {
                logger.log(&format!("   Types: {}", types.join(", ")));
            }
            if threads > 1 {
                logger.log(&format!("   Concurrent Threads: {}", threads));
            }
            if retries > 1 {
                logger.log(&format!("   Retries per Thread: {}", retries));
            }
            logger.log(&format!("   Log File: {}", log_path.display()));
            logger.log("");

            let result = client
                .book_competitive(
                    &venue_id,
                    party_size,
                    &date,
                    &times,
                    &types,
                    dry_run,
                    threads,
                    retries,
                    Duration::from_millis(poll_interval_ms),
                    Duration::from_secs(poll_timeout_secs),
                    logger.clone_handle(),
                )
                .await;

            match &result {
                Ok(_) => {
                    logger.log("");
                    logger.log("═══════════════════════════════════════════════════════");
                    logger.log("✅ Booking completed successfully");
                }
                Err(e) => {
                    logger.log("");
                    logger.log("═══════════════════════════════════════════════════════");
                    logger.log(&format!("❌ Booking failed: {}", e));
                }
            }

            result?;
        }
    }

    Ok(())
}

