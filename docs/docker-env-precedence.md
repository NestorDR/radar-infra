# Docker environment variables: Precedence

When the same variable is defined in multiple places, Docker applies this precedence from highest to lowest:

1. `docker run -e`
2. `docker-compose.yml` `environment`
3. `env_file`
4. `docker-compose.yml` `env_file`
5. `Dockerfile` `ENV`
6. Values inherited from the host

## Example

If `LOG_LEVEL` is set in both `docker run -e LOG_LEVEL=warn` and in an env file as `LOG_LEVEL=info`, Docker uses `warn` because `-e` wins.

## Practical rule

Use `-e` for the value that must override everything else, and use `--env-file` for defaults or grouped configuration.