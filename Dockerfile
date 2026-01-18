# Build stage
FROM gradle:8.5-jdk21 AS build

WORKDIR /app

# Copy Gradle wrapper and build files first (for better caching)
COPY gradle/ gradle/
COPY build.gradle settings.gradle ./
COPY gradlew* ./

# Fix line endings and set executable permission
RUN sed -i 's/\r$//' gradlew && \
    chmod +x gradlew && \
    ls -la gradlew && \
    echo "=== Testing gradlew ===" && \
    ./gradlew --version

# Copy source code
COPY src/ src/

# Verify files are copied correctly
RUN echo "=== Verifying source files ===" && \
    find src -type f -name "*.java" | head -5 && \
    ls -la build.gradle settings.gradle

# Build the application step by step for better error visibility
RUN echo "=== Starting Gradle build ===" && \
    ./gradlew clean --no-daemon --stacktrace

RUN echo "=== Compiling Java code ===" && \
    ./gradlew compileJava --no-daemon --stacktrace

RUN echo "=== Processing resources ===" && \
    ./gradlew processResources --no-daemon --stacktrace

RUN echo "=== Building JAR ===" && \
    ./gradlew bootJar --no-daemon --stacktrace

# Verify JAR file was created
RUN echo "=== Checking JAR files ===" && \
    ls -la build/libs/ && \
    find build/libs -name "*.jar" || (echo "JAR file not found!" && exit 1)

# Runtime stage
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Install wget for health check
RUN apk add --no-cache wget

# Create non-root user
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Copy the built JAR from build stage
COPY --from=build --chown=spring:spring /app/build/libs/*.jar app.jar

# Expose port
EXPOSE 8080

# Health check (using root endpoint since actuator is not included)
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
