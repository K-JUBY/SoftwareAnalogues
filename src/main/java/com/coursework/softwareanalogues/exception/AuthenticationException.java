package com.coursework.softwareanalogues.exception;

public final class AuthenticationException extends AppException {
    public AuthenticationException(String message) {
        super(message);
    }

    public AuthenticationException(String message, Throwable cause) {
        super(message, cause);
    }
}
