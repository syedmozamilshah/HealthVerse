using System.Text.RegularExpressions;

namespace BlazorUI.Services;

public static class ValidationService
{
    #region Regex Patterns

    public static readonly Regex EmailRegex = new(
        @"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
        RegexOptions.Compiled);

    public static readonly Regex PhoneRegex = new(
        @"^(03[0-9]{2}[0-9]{7}|92[0-9]{10}|\+92[0-9]{10})$",
        RegexOptions.Compiled);

    public static readonly Regex InternationalPhoneRegex = new(
        @"^\+?[0-9]{10,15}$",
        RegexOptions.Compiled);
    public static readonly Regex NameRegex = new(
        @"^[a-zA-Z\s\-']{2,50}$",
        RegexOptions.Compiled);
    public static readonly Regex PasswordRegex = new(
        @"^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{6,}$",
        RegexOptions.Compiled);

    public static readonly Regex StrongPasswordRegex = new(
        @"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$",
        RegexOptions.Compiled);

    public static readonly Regex CnicRegex = new(
        @"^[0-9]{5}-[0-9]{7}-[0-9]$",
        RegexOptions.Compiled);
    public static readonly Regex CnicWithoutDashRegex = new(
        @"^[0-9]{13}$",
        RegexOptions.Compiled);

    public static readonly Regex PmdcRegex = new(
        @"^[0-9]{1,10}-[A-Z]$|^[0-9]{1,10}$",
        RegexOptions.Compiled);
    public static readonly Regex AgeRegex = new(
        @"^(1[0-4][0-9]|150|[1-9][0-9]|[1-9])$",
        RegexOptions.Compiled);

    public static readonly Regex LettersOnlyRegex = new(
        @"^[a-zA-Z\s]+$",
        RegexOptions.Compiled);

    public static readonly Regex DigitsOnlyRegex = new(
        @"^[0-9]+$",
        RegexOptions.Compiled);

    public static readonly Regex MedicalLicenseRegex = new(
        @"^[A-Za-z0-9\-]{5,20}$",
        RegexOptions.Compiled);

    public static readonly Regex FeeRegex = new(
        @"^[0-9]+(\.[0-9]{1,2})?$",
        RegexOptions.Compiled);

    public static readonly Regex UrlRegex = new(
        @"^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$",
        RegexOptions.Compiled);

    #endregion

    #region Validation Functions
    public static (bool IsValid, string? ErrorMessage) ValidateEmail(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, "Email is required");

        if (!EmailRegex.IsMatch(value.Trim()))
            return (false, "Please enter a valid email address");

        return (true, null);
    }

    public static (bool IsValid, string? ErrorMessage) ValidatePhone(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, "Phone number is required");

        var cleanPhone = Regex.Replace(value, @"[\s\-()]", "");
        if (!PhoneRegex.IsMatch(cleanPhone) && !InternationalPhoneRegex.IsMatch(cleanPhone))
            return (false, "Please enter a valid phone number (e.g., 03XX-XXXXXXX)");

        return (true, null);
    }
    public static (bool IsValid, string? ErrorMessage) ValidateName(string? value, string fieldName = "Name")
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, $"{fieldName} is required");

        if (value.Trim().Length < 2)
            return (false, $"{fieldName} must be at least 2 characters");

        if (value.Trim().Length > 50)
            return (false, $"{fieldName} must not exceed 50 characters");

        if (!NameRegex.IsMatch(value.Trim()))
            return (false, $"{fieldName} can only contain letters, spaces, hyphens, and apostrophes");

        return (true, null);
    }

    public static (bool IsValid, string? ErrorMessage) ValidatePassword(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, "Password is required");

        if (value.Length < 6)
            return (false, "Password must be at least 6 characters");

        if (!PasswordRegex.IsMatch(value))
            return (false, "Password must contain at least one letter and one number");

        return (true, null);
    }
    public static (bool IsValid, string? ErrorMessage) ValidateStrongPassword(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, "Password is required");

        if (value.Length < 8)
            return (false, "Password must be at least 8 characters");

        if (!StrongPasswordRegex.IsMatch(value))
            return (false, "Password must contain uppercase, lowercase, number, and special character");

        return (true, null);
    }

    public static (bool IsValid, string? ErrorMessage) ValidateConfirmPassword(string? value, string originalPassword)
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, "Please confirm your password");

        if (value != originalPassword)
            return (false, "Passwords do not match");

        return (true, null);
    }

    public static (bool IsValid, string? ErrorMessage) ValidateCnic(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, "CNIC is required");

        var cleanCnic = value.Replace("-", "");
        if (!CnicWithoutDashRegex.IsMatch(cleanCnic))
            return (false, "Please enter a valid CNIC (XXXXX-XXXXXXX-X)");

        return (true, null);
    }

    public static (bool IsValid, string? ErrorMessage) ValidatePmdc(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, "PMDC number is required");

        if (!PmdcRegex.IsMatch(value.Trim()))
            return (false, "Please enter a valid PMDC number");

        return (true, null);
    }

    public static (bool IsValid, string? ErrorMessage) ValidateAge(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, "Age is required");

        if (!AgeRegex.IsMatch(value))
            return (false, "Please enter a valid age (1-150)");

        return (true, null);
    }
    public static (bool IsValid, string? ErrorMessage) ValidateFee(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, "Fee is required");

        if (!FeeRegex.IsMatch(value))
            return (false, "Please enter a valid fee amount");

        return (true, null);
    }

    public static (bool IsValid, string? ErrorMessage) ValidateRequired(string? value, string fieldName = "This field")
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, $"{fieldName} is required");

        return (true, null);
    }

    public static (bool IsValid, string? ErrorMessage) ValidateMinLength(string? value, int minLength, string fieldName = "This field")
    {
        if (string.IsNullOrWhiteSpace(value))
            return (false, $"{fieldName} is required");

        if (value.Length < minLength)
            return (false, $"{fieldName} must be at least {minLength} characters");

        return (true, null);
    }

    public static (bool IsValid, string? ErrorMessage) ValidateMaxLength(string? value, int maxLength, string fieldName = "This field")
    {
        if (value != null && value.Length > maxLength)
            return (false, $"{fieldName} must not exceed {maxLength} characters");

        return (true, null);
    }

    #endregion

    #region Helper Functions

    public static bool Matches(string value, Regex pattern) => pattern.IsMatch(value);

    public static string FormatPhoneNumber(string phone)
    {
        var clean = Regex.Replace(phone, @"[\s\-()]", "");
        if (clean.Length == 11 && clean.StartsWith("03"))
            return $"{clean.Substring(0, 4)}-{clean.Substring(4)}";
        return phone;
    }

    public static string FormatCnic(string cnic)
    {
        var clean = cnic.Replace("-", "");
        if (clean.Length == 13)
            return $"{clean.Substring(0, 5)}-{clean.Substring(5, 7)}-{clean.Substring(12)}";
        return cnic;
    }

    #endregion
}
