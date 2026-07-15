# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability within this project, please report it through our 
[Vulnerability Reporting Policy](https://www.mercedes-benz.com/en/whitehat/).

We ask that you do not publicly disclose the issue until we have had a chance to address it.

## Security Best Practices

When using this package:

1. **Sensitive Data**: Be mindful that SCD2 snapshots retain historical data. Ensure your data 
   retention policies comply with your organization's security and privacy requirements.

2. **Access Control**: Use appropriate database-level permissions to restrict access to snapshot 
   tables that may contain sensitive information.

3. **Metadata Tables**: The package creates metadata and error log tables. Review what information 
   is stored and ensure it doesn't expose sensitive data.

## Supported Versions

We provide security updates for the latest minor version of each major release.

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
