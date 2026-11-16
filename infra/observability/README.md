# Observability (phase 2 — design §10)

Empty by design for now. The stack is prepared for it:

- Nginx access log already carries `$request_id` for correlation.
- Services will emit structured JSON logs from day one (`logstash-logback-encoder`)
  and propagate correlation/request IDs across gateway → services → Kafka headers.
- Planned additions here: Prometheus scrape config, Grafana dashboards/datasources,
  OpenTelemetry collector config — wired via an observability compose overlay.
