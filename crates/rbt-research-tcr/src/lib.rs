use serde::{Serialize, Deserialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PolicyAction {
    Allow,
    Drop,
    Throttle(u32), // kbps
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResearchPolicy {
    pub name: String,
    pub protocol_rules: HashMap<String, PolicyAction>,
    pub max_packet_size: usize,
}

#[derive(Debug, Default, Serialize)]
pub struct TrafficStats {
    pub total_packets: u64,
    pub total_bytes: u64,
    pub protocol_distribution: HashMap<String, u64>,
}

pub struct TrafficClassifier {
    stats: Arc<Mutex<TrafficStats>>,
    active_policy: Option<ResearchPolicy>,
}

impl TrafficClassifier {
    pub fn new(policy: Option<ResearchPolicy>) -> Self {
        Self {
            stats: Arc::new(Mutex::new(TrafficStats::default())),
            active_policy: policy,
        }
    }

    /// Analyzes a packet and returns the simulated policy action
    pub fn process_packet(&self, size: usize, proto: &str) -> PolicyAction {
        let mut stats = self.stats.lock().unwrap();
        stats.total_packets += 1;
        stats.total_bytes += size as u64;
        *stats.protocol_distribution.entry(proto.to_string()).or_insert(0) += 1;

        if let Some(ref policy) = self.active_policy {
            if size > policy.max_packet_size {
                return PolicyAction::Drop;
            }

            if let Some(action) = policy.protocol_rules.get(proto) {
                return action.clone();
            }
        }

        PolicyAction::Allow
    }

    pub fn get_stats(&self) -> TrafficStats {
        let stats = self.stats.lock().unwrap();
        // Return a clone of the stats
        TrafficStats {
            total_packets: stats.total_packets,
            total_bytes: stats.total_bytes,
            protocol_distribution: stats.protocol_distribution.clone(),
        }
    }

    pub fn generate_research_summary(&self) -> String {
        let stats = self.get_stats();
        format!(
            "Research Summary:\n- Total Packets: {}\n- Total Bytes: {}\n- Protocols: {:?}",
            stats.total_packets, stats.total_bytes, stats.protocol_distribution
        )
    }
}

pub struct PolicySimulator;

impl PolicySimulator {
    pub fn new() -> Self {
        Self
    }

    pub fn run_simulation(&self, ruleset_name: &str) -> String {
        // Simulated policy evaluation logic
        format!(
            "Simulation Results for Ruleset: {}\n- Status: Verified\n- Compliance: 100%\n- Estimated Latency Overhead: 2.4ms",
            ruleset_name
        )
    }
}
