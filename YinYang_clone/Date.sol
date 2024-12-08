// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Date {
    uint256 constant SECONDS_IN_HOUR = 3600;
    uint256 constant SECONDS_IN_DAY = 86400;
    uint256 constant SECONDS_IN_YEAR = 31536000;
    uint256 constant SECONDS_IN_LEAP_YEAR = 31622400;

    uint16 constant ORIGIN_YEAR = 1970;

    // Get the number of hours in a month based on the timestamp
    function getHoursInMonth(uint256 _timestamp) internal pure returns (uint256) {
        uint16 year = getYear(_timestamp);
        uint8 month = getMonth(_timestamp);
        uint256 daysInMonth = getDaysInMonth(month, year);
        
        return daysInMonth * 24; // Hours in the month
    }

    // Get the number of days in a month (handling leap years for February)
    function getDaysInMonth(uint8 month, uint16 year) internal pure returns (uint8) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            return 31;
        } else if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        } else if (isLeapYear(year)) {
            return 29;
        } else {
            return 28;
        }
    }

    // Determine if the given year is a leap year
    function isLeapYear(uint16 year) internal pure returns (bool) {
        if (year % 4 != 0) {
            return false;
        }
        if (year % 100 != 0) {
            return true;
        }
        if (year % 400 != 0) {
            return false;
        }
        return true;
    }

    // Calculate the year from the timestamp
    function getYear(uint256 _timestamp) internal pure returns (uint16) {
        uint256 secondsAccountedFor = 0;
        uint16 year = uint16(ORIGIN_YEAR + _timestamp / SECONDS_IN_YEAR);
        uint256 leapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += SECONDS_IN_LEAP_YEAR * leapYears;
        secondsAccountedFor += SECONDS_IN_YEAR * (year - ORIGIN_YEAR - leapYears);

        // Adjust if overestimated
        while (secondsAccountedFor > _timestamp) {
            year -= 1;
            secondsAccountedFor -= isLeapYear(year) ? SECONDS_IN_LEAP_YEAR : SECONDS_IN_YEAR;
        }

        return year;
    }

    // Calculate the month from the timestamp
    function getMonth(uint256 _timestamp) internal pure returns (uint8) {
        uint16 year = getYear(_timestamp);
        uint256 secondsAccountedFor = 0;
        uint256 secondsInMonth;

        for (uint8 month = 1; month <= 12; month++) {
            secondsInMonth = SECONDS_IN_DAY * getDaysInMonth(month, year);
            if (_timestamp < secondsAccountedFor + secondsInMonth) {
                return month;
            }
            secondsAccountedFor += secondsInMonth;
        }
        return 1; // Fallback (should never hit)
    }

    // Calculate leap years before a specific year
    function leapYearsBefore(uint16 year) internal pure returns (uint256) {
        year -= 1;
        return year / 4 - year / 100 + year / 400;
    }
}
