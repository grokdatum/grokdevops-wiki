#!/bin/bash
# This script should display a greeting with the user's name

USERNAME="DevOps Engineer"

# BUG: Single quotes prevent variable expansion
echo 'Hello, $USERNAME! Welcome to the system.'
