FROM eclipse-temurin:21-jdk AS builder

WORKDIR /workspace

# Copy the entire project
COPY . .

# Build the project using Maven wrapper (skipping tests for speed)
# -pl quarkus/deployment,quarkus/dist -am builds only the server distribution
# We set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 because Kiota (.NET Core) is used 
# during the frontend build and it crashes without this env var in stripped down containers.
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
RUN ./mvnw -pl quarkus/deployment,quarkus/dist -am -DskipTests clean install

# Unpack the generated zip distribution
RUN apt-get update && \
    apt-get install -y unzip && \
    mkdir -p /workspace/dist && \
    unzip quarkus/dist/target/keycloak-*.zip -d /workspace/dist && \
    mv /workspace/dist/keycloak-* /workspace/keycloak-runnable

# Runtime stage using a lightweight JRE image
FROM eclipse-temurin:21-jre

ENV LANG=en_US.UTF-8
ENV KC_RUN_IN_CONTAINER=true

# Copy the unpacked Keycloak distribution from the builder stage
COPY --from=builder /workspace/keycloak-runnable /opt/keycloak

# Ensure the scripts are executable
RUN chmod -R +x /opt/keycloak/bin

# Expose standard Keycloak ports
EXPOSE 8080
EXPOSE 8443
EXPOSE 9000

# Set the entrypoint to the Keycloak script
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
