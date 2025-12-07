package com.cloakworks.userservice.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.web.client.RestOperations;
import org.springframework.web.client.RestTemplate;

import javax.net.ssl.*;
import java.security.cert.X509Certificate;

/**
 * Configuration to trust self-signed certificates for Keycloak JWK set retrieval.
 * This is for development/testing only. In production, use proper CA-signed certificates.
 */
@Configuration
public class KeycloakSslConfig {

    @Bean
    public RestOperations restOperations() {
        try {
            // Create a trust manager that accepts all certificates
            TrustManager[] trustAllCerts = new TrustManager[]{
                    new X509TrustManager() {
                        public X509Certificate[] getAcceptedIssuers() {
                            return new X509Certificate[0];
                        }

                        public void checkClientTrusted(X509Certificate[] certs, String authType) {
                        }

                        public void checkServerTrusted(X509Certificate[] certs, String authType) {
                        }
                    }
            };

            // Install the all-trusting trust manager
            SSLContext sslContext = SSLContext.getInstance("TLS");
            sslContext.init(null, trustAllCerts, new java.security.SecureRandom());

            // Create request factory with custom SSL context
            SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory() {
                @Override
                protected void prepareConnection(java.net.HttpURLConnection connection, String httpMethod) {
                    if (connection instanceof javax.net.ssl.HttpsURLConnection) {
                        javax.net.ssl.HttpsURLConnection httpsConnection = (javax.net.ssl.HttpsURLConnection) connection;
                        try {
                            httpsConnection.setSSLSocketFactory(sslContext.getSocketFactory());
                            httpsConnection.setHostnameVerifier((hostname, session) -> true);
                        } catch (Exception e) {
                            throw new RuntimeException(e);
                        }
                    }
                }
            };

            return new RestTemplate(factory);
        } catch (Exception e) {
            throw new RuntimeException("Failed to create RestOperations with SSL trust", e);
        }
    }

    @Bean
    public JwtDecoder jwtDecoder(RestOperations restOperations) {
        String issuerUri = System.getenv("KEYCLOAK_ISSUER_URI");
        if (issuerUri == null || issuerUri.isEmpty()) {
            issuerUri = "http://keycloak.keycloak.svc.cluster.local:8080/realms/microservices";
        }

        // Build JWK set URI from issuer URI
        String jwkSetUri = issuerUri + "/protocol/openid-connect/certs";

        return NimbusJwtDecoder.withJwkSetUri(jwkSetUri)
                .restOperations(restOperations)
                .build();
    }
}

