FROM eclipse-temurin:17-jre

LABEL authors="adalj8d"
RUN mkdir -p /app
WORKDIR /app

ARG JAR_FILE=target/demo-1.0.0.ja
#COPY ${JAR_FILE} app.jar
COPY maven/${JAR_FILE} app.jar
#COPY target/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
