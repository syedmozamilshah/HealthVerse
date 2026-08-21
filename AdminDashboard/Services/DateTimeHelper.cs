using System;
using System.Text.RegularExpressions;

namespace AdminDashboard.Services
{
    /// <summary>
    /// Helper class for handling date/time conversions to Pakistan Standard Time (UTC+5).
    /// Ensures all incoming dates from API are treated as UTC and converted to Pakistan time.
    /// </summary>
    public static class DateTimeHelper
    {
        private static readonly TimeZoneInfo PakistanTimeZone = GetPakistanTimeZone();

        private static TimeZoneInfo GetPakistanTimeZone()
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById("Asia/Karachi");
            }
            catch (TimeZoneNotFoundException)
            {
                return TimeZoneInfo.FindSystemTimeZoneById("Pakistan Standard Time");
            }
            catch (InvalidTimeZoneException)
            {
                return TimeZoneInfo.FindSystemTimeZoneById("Pakistan Standard Time");
            }
        }

        /// <summary>
        /// Converts a DateTime to Pakistan time and formats it with the specified format string.
        /// Treats unspecified DateTime as UTC.
        /// </summary>
        public static string ToDisplayString(this DateTime dt, string format)
        {
            try
            {
                // Ensure UTC kind
                DateTime utcDate = dt.Kind == DateTimeKind.Unspecified
                    ? DateTime.SpecifyKind(dt, DateTimeKind.Utc)
                    : (dt.Kind == DateTimeKind.Local ? dt.ToUniversalTime() : dt);

                // Convert to Pakistan time
                DateTime pakistanTime = TimeZoneInfo.ConvertTime(utcDate, PakistanTimeZone);

                return pakistanTime.ToString(format);
            }
            catch
            {
                // Fallback to original formatting if conversion fails
                return dt.ToString(format);
            }
        }

        /// <summary>
        /// Parses a date string as UTC (equivalent to appending 'Z' to ISO format).
        /// If the string doesn't have timezone info, it's treated as UTC.
        /// </summary>
        public static DateTime ParseAsUtc(string dateString)
        {
            if (string.IsNullOrEmpty(dateString))
                return DateTime.MinValue;

            // If no timezone indicator, append Z to force UTC
            if (!dateString.EndsWith("Z", StringComparison.OrdinalIgnoreCase) &&
                !Regex.IsMatch(dateString, @"[+-]\d{2}:?\d{2}$"))
            {
                dateString += "Z";
            }

            if (DateTime.TryParse(dateString, null, System.Globalization.DateTimeStyles.RoundtripKind, out var result))
                return result;

            return DateTime.MinValue;
        }

        /// <summary>
        /// Converts a nullable DateTime to Pakistan time and formats it.
        /// </summary>
        public static string ToDisplayString(this DateTime? dt, string format)
        {
            return dt.HasValue ? dt.Value.ToDisplayString(format) : string.Empty;
        }

        /// <summary>
        /// Gets current Pakistan time (useful for comparisons).
        /// </summary>
        public static DateTime GetPakistanNow()
        {
            return TimeZoneInfo.ConvertTime(DateTime.UtcNow, PakistanTimeZone);
        }

        /// <summary>
        /// Compares two dates in Pakistan timezone (ignoring time component).
        /// </summary>
        public static bool IsSameDateInPakistan(this DateTime dt1, DateTime dt2)
        {
            var pak1 = TimeZoneInfo.ConvertTime(
                dt1.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(dt1, DateTimeKind.Utc) : dt1,
                PakistanTimeZone);
            
            var pak2 = TimeZoneInfo.ConvertTime(
                dt2.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(dt2, DateTimeKind.Utc) : dt2,
                PakistanTimeZone);

            return pak1.Date == pak2.Date;
        }
    }
}
