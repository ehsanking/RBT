# RBT Operational & Engineering Notes

## Operational Notes
- **Resource Limits**: RBT is designed for high-concurrency. Ensure `ulimit -n` is set to at least `1048576` on the host.
- **Log Rotation**: Logs are stored in `/var/log/rbt`. Use `logrotate` to prevent disk exhaustion.
- **Zero-Downtime Reloads**: Sending `SIGHUP` to the RBT process triggers a configuration reload without dropping existing active tunnels.
- **ACME Staging**: During initial setup, use the ACME staging endpoint to avoid Let's Encrypt rate limits.

## Testing Strategy
- **Unit Testing**: Each crate (`rbt-config`, `rbt-core`) contains unit tests for logic validation. Run with `cargo test`.
- **Integration Testing**: The `tests/` directory contains end-to-end tests that spawn mock `rstun` processes and verify connectivity.
- **Fuzz Testing**: Use `cargo-fuzz` on the TOML parser to ensure robustness against malformed configurations.
- **Simulation Mode**: Use `rbt simulate` to benchmark routing table lookups with large datasets (e.g., 100k+ rules) without network I/O.

## Future Roadmap
- **v0.1.0**: Integration with `eBPF` for high-performance packet steering.
- **v0.2.0**: Web-based monitoring dashboard (Read-only) for real-time tunnel metrics.
- **v0.3.0**: Support for hardware security modules (HSM) for TLS key storage.
- **v0.4.0**: Advanced traffic classification research tools for regional policy analysis.

## Research Objectives (Completed)
- [x] QUIC transport stability analysis.
- [x] ACME lifecycle automation.
- [x] Bounded exponential backoff implementation.
- [x] Hardened systemd service profile.
