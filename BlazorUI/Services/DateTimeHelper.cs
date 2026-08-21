using System;
using System.Globalization;

namespace BlazorUI.Services
{
    /// <summary>
    /// Helper class for handling date/time conversions to Pakistan Standard Time (UTC+5).
    /// Assumes API sends UTC or UTC-compatible DateTime values.
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
        /// Converts DateTime to Pakistan time and formats it safely.
        /// </summary>
        public static string ToDisplayString(this DateTime dt, string format)
        {
            try
            {
                var utc = NormalizeToUtc(dt);
                var pkTime = TimeZoneInfo.ConvertTimeFromUtc(utc, PakistanTimeZone);
                return pkTime.ToString(format);
            }
            catch
            {
                return dt.ToString(format);
            }
        }

        /// <summary>
        /// Nullable overload
        /// </summary>
        public static string ToDisplayString(this DateTime? dt, string format)
        {
            return dt.HasValue ? dt.Value.ToDisplayString(format) : string.Empty;
        }

        /// <summary>
        /// Returns current Pakistan time
        /// </summary>
        public static DateTime GetPakistanNow()
        {
            return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, PakistanTimeZone);
        }

        /// <summary>
        /// Compares only DATE part in Pakistan timezone (safe version)
        /// </summary>
        public static bool IsSameDateInPakistan(this DateTime dt1, DateTime dt2)
        {
            var pk1 = TimeZoneInfo.ConvertTimeFromUtc(NormalizeToUtc(dt1), PakistanTimeZone);
            var pk2 = TimeZoneInfo.ConvertTimeFromUtc(NormalizeToUtc(dt2), PakistanTimeZone);

            return pk1.Date == pk2.Date;
        }

        /// <summary>
        /// Safely parses ISO or normal date strings into UTC DateTime
        /// </summary>
        public static DateTime ParseAsUtc(string dateString)
        {
            if (string.IsNullOrWhiteSpace(dateString))
                return DateTime.MinValue;

            if (DateTime.TryParse(
                dateString,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                out var result))
            {
                return result;
            }

            return DateTime.MinValue;
        }

        /// <summary>
        /// Ensures DateTime is treated as UTC safely
        /// </summary>
        private static DateTime NormalizeToUtc(DateTime dt)
        {
            return dt.Kind switch
            {
                DateTimeKind.Utc => dt,
                DateTimeKind.Local => dt.ToUniversalTime(),
                _ => DateTime.SpecifyKind(dt, DateTimeKind.Utc)
            };
        }
    }
}