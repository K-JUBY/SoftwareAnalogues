package com.coursework.softwareanalogues.dao;

import com.coursework.softwareanalogues.model.User;

import java.util.Optional;

/** Provides access to application user authentication data. */
public interface UserDao {
    /**
     * Authenticates a user through PostgreSQL function `authenticate_user`.
     *
     * @param username login entered by user
     * @param password plain password entered in the login form; it is not stored by Java code
     * @return authenticated user if credentials are valid
     */
    Optional<User> authenticate(String username, String password);
}
