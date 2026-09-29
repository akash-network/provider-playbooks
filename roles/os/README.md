This ansible role covers the tasks to setup sysctl and cron job configuration.
# OS role

Applies Ubuntu provider-node prerequisites, sysctl settings, journal cleanup,
SSH hardening, and a zombie process cleanup cron job. Run this role only after preflight has
confirmed SSH access and the supported Ubuntu release.
