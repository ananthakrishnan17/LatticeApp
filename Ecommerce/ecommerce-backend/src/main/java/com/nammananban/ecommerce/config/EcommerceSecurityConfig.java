package com.nammananban.ecommerce.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
public class EcommerceSecurityConfig {
    @Bean
    SecurityFilterChain ecommerceFilterChain(HttpSecurity http, EcJwtAuthFilter ecJwtAuthFilter) throws Exception {
        http
                .csrf(csrf -> csrf.ignoringRequestMatchers("/ec/**"))
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(
                                "/ec/store/**", "/ec/auth/**", "/ec/cart/**", "/ec/checkout/**",
                                "/ec/events", "/ec/stock-alerts",
                                "/ec/qa/{listingId:\\b[0-9a-f-]{36}\\b}",
                                "/actuator/health"
                        ).permitAll()
                        .requestMatchers("/ec/admin/**", "/ec/qa/admin/**").hasAuthority("EC_ADMIN")
                        .anyRequest().authenticated())
                .addFilterBefore(ecJwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
                .httpBasic(basic -> basic.disable());
        return http.build();
    }
}
