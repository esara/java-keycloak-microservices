package com.cloakworks.gateway.config;

import io.netty.handler.ssl.SslContext;
import io.netty.handler.ssl.SslContextBuilder;
import io.netty.handler.ssl.util.InsecureTrustManagerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.security.oauth2.jwt.NimbusReactiveJwtDecoder;
import org.springframework.security.oauth2.jwt.ReactiveJwtDecoder;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

import javax.net.ssl.SSLException;

@Configuration
public class KeycloakSslConfig {

    /**
     * Configure WebClient to trust self-signed certificates for Keycloak JWK set retrieval.
     * This is for development/testing only. In production, use proper CA-signed certificates.
     *
     * Note: Using Spring's WebClient.Builder (if available) ensures OpenTelemetry instrumentation
     * is applied. If WebClient.Builder is not available, falls back to manual WebClient creation.
     */
    @Bean
    public ReactiveJwtDecoder jwtDecoder(org.springframework.beans.factory.ObjectProvider<WebClient.Builder> webClientBuilderProvider) throws SSLException {
        // Create SSL context that trusts all certificates (for development with self-signed certs)
        SslContext sslContext = SslContextBuilder
                .forClient()
                .trustManager(InsecureTrustManagerFactory.INSTANCE)
                .build();

        HttpClient httpClient = HttpClient.create()
                .secure(sslContextSpec -> sslContextSpec.sslContext(sslContext));

        // Use Spring's WebClient.Builder if available (for OpenTelemetry instrumentation),
        // otherwise create manually
        WebClient webClient;
        WebClient.Builder builder = webClientBuilderProvider.getIfAvailable();
        if (builder != null) {
            // Use Spring's builder which includes instrumentation
            webClient = builder
                    .clientConnector(new ReactorClientHttpConnector(httpClient))
                    .build();
        } else {
            // Fallback to manual creation (no instrumentation)
            webClient = WebClient.builder()
                    .clientConnector(new ReactorClientHttpConnector(httpClient))
                    .build();
        }

        // Get issuer URI from environment or use default
        String issuerUri = System.getenv("KEYCLOAK_ISSUER_URI");
        if (issuerUri == null || issuerUri.isEmpty()) {
            issuerUri = "http://keycloak.keycloak.svc.cluster.local:8080/realms/microservices";
        }

        // Build JWK set URI from issuer URI
        String jwkSetUri = issuerUri + "/protocol/openid-connect/certs";

        return NimbusReactiveJwtDecoder.withJwkSetUri(jwkSetUri)
                .webClient(webClient)
                .build();
    }
}

