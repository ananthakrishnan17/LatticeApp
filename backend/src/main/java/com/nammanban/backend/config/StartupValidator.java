package com.nammanban.backend.config;

import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

import java.util.ArrayList;
import java.util.List;

/**
 * Validates that all required environment variables are present at startup.
 * Throws a clear {@link IllegalStateException} listing every missing variable
 * so the operator knows exactly what to set before the app is retried.
 */
@Configuration
public class StartupValidator {

    @Value("${spring.datasource.url:#{null}}")
    private String dbUrl;

    @Value("${spring.datasource.username:#{null}}")
    private String dbUsername;

    @Value("${spring.datasource.password:#{null}}")
    private String dbPassword;

    @Value("${app.jwt.secret:#{null}}")
    private String jwtSecret;

    @PostConstruct
    public void validate() {
        List<String> missing = new ArrayList<>();

        if (isBlank(dbUrl)) {
            missing.add("DB_URL (spring.datasource.url)");
        }
        if (isBlank(dbUsername)) {
            missing.add("DB_USERNAME (spring.datasource.username)");
        }
        if (isBlank(dbPassword)) {
            missing.add("DB_PASSWORD (spring.datasource.password)");
        }
        if (isBlank(jwtSecret)) {
            missing.add("JWT_SECRET (app.jwt.secret)");
        } else if (jwtSecret.length() < 32) {
            missing.add("JWT_SECRET (app.jwt.secret) — value is too short ("
                    + jwtSecret.length() + " chars); must be at least 32 characters for HMAC-SHA256");
        }

        if (!missing.isEmpty()) {
            throw new IllegalStateException(
                    "Application cannot start — the following required environment variables are not set:\n  "
                            + String.join("\n  ", missing)
                            + "\nSet them in $CATALINA_HOME/bin/setenv.sh (Tomcat) or as system environment variables.");
        }
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
