mod api;
mod types;

use anyhow::{Context, Result};
use clap::Parser;
use std::env;

use api::ResyClient;

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
    },
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
        } => {
            let types = types.unwrap_or_default();
            
            println!("🚀 Starting Resy booking...");
            println!("   Venue ID: {}", venue_id);
            println!("   Party Size: {}", party_size);
            println!("   Date: {}", date);
            if !times.is_empty() {
                println!("   Times: {}", times.join(", "));
            }
            if !types.is_empty() {
                println!("   Types: {}", types.join(", "));
            }
            println!();

            client
                .book(&venue_id, party_size, &date, &times, &types, dry_run)
                .await?;
        }
    }

    Ok(())
}

