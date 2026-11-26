#!/bin/sh
set -eu
# Free Render services have no pre-deploy phase. Run migrations sequentially
# before opening the HTTP listener; a migration failure prevents startup.
if [ "${MIGRATE_ON_START:-false}" = "true" ] && [ "${1:-}" = "serve" ]; then
    ./RealPacmanServer migrate --yes --env production
fi
exec ./RealPacmanServer "$@"
