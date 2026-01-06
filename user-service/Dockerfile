FROM maven:3.9-ibm-semeru-21-noble AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:21
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
RUN curl -s -P /app -OL https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.23.0/opentelemetry-javaagent.jar
ENTRYPOINT ["java", "-javaagent:opentelemetry-javaagent.jar", "-jar", "app.jar"]
