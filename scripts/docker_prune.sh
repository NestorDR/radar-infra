
# 1. Check disk space usage
df -h /opt/radar/infra/database/data

# 2. Check inode usage (if disk has free space, inodes might be 100% full)
df -i /opt/radar/infra/database/data

# 3. Check Docker resource usage
docker system df

# 4. Remove stopped containers before image pruning so their now-unused images can be reclaimed safely.
docker container prune -f

# 5. Remove unused images without touching Docker volumes or bind-mounted application data.
docker image prune -a -f

# 6. Remove unused Docker networks while preserving networks still attached to containers.
docker network prune -f

# 7. Remove unused build cache without including persistent Docker volumes in the cleanup scope.
docker builder prune -a -f
