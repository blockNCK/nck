echo "DELETING DOCKER CONTAINERS"
docker container stop $(docker container ls -aq)
docker container rm $(docker container ls -aq)
docker container prune --force
docker system prune -a --force
docker network prune --force
docker volume prune --force
docker image prune -a --force


# docker system prune -a --force
echo 'DELETEING CRYPTO FILES'
cd nck-network
rm -rf channel-artifacts
rm -rf crypto-configs