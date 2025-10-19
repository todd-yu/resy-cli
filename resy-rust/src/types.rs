use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize)]
pub struct BookingConfig {
    pub config_id: String,
    pub day: String,
    pub party_size: u32,
}

#[derive(Debug, Deserialize)]
pub struct FindResponse {
    pub results: Results,
}

#[derive(Debug, Deserialize)]
pub struct Results {
    pub venues: Vec<Venue>,
}

#[derive(Debug, Deserialize)]
pub struct Venue {
    pub slots: Vec<Slot>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Slot {
    pub date: SlotDate,
    pub config: SlotConfig,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SlotDate {
    pub start: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SlotConfig {
    #[serde(rename = "type")]
    pub slot_type: String,
    pub token: String,
}

#[derive(Debug, Deserialize)]
pub struct VenueResponse {
    pub venue: VenueInfo,
}

#[derive(Debug, Deserialize)]
pub struct VenueInfo {
    pub name: String,
}

#[derive(Debug, Deserialize)]
pub struct DetailsResponse {
    pub book_token: BookToken,
    pub user: User,
}

#[derive(Debug, Deserialize)]
pub struct BookToken {
    pub value: String,
}

#[derive(Debug, Deserialize)]
pub struct User {
    pub payment_methods: Option<Vec<PaymentMethod>>,
}

#[derive(Debug, Deserialize)]
pub struct PaymentMethod {
    pub id: u64,
}

impl Slot {
    pub fn matches(&self, times: &[String], types: &[String]) -> bool {
        let slot_time = self.date.start.split_whitespace().nth(1).unwrap_or("");
        let slot_type = self.config.slot_type.to_lowercase();
        
        let time_match = times.is_empty() || times.iter().any(|t| t == slot_time);
        let type_match = types.is_empty() || types.iter().any(|t| t.to_lowercase() == slot_type);
        
        time_match && type_match
    }
}
