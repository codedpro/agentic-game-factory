class_name Jalali
extends RefCounted
## Gregorian <-> Jalali (Persian) calendar conversion + Persian date formatting.
## Iranian players expect Persian dates; it also lets us detect یلدا and نوروز.

const MONTHS := ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
	"مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"]
const _G_DAYS := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]


## [jy, jm, jd] from a Gregorian date.
static func from_gregorian(gy: int, gm: int, gd: int) -> Array:
	var jy := 0
	if gy > 1600:
		jy = 979
		gy -= 1600
	else:
		gy -= 621
	var gy2 := gy + 1 if gm > 2 else gy
	var days: int = (365 * gy) + int((gy2 + 3) / 4.0) - int((gy2 + 99) / 100.0) \
		+ int((gy2 + 399) / 400.0) - 80 + gd + _G_DAYS[gm - 1]
	jy += 33 * int(days / 12053.0)
	days %= 12053
	jy += 4 * int(days / 1461.0)
	days %= 1461
	if days > 365:
		jy += int((days - 1) / 365.0)
		days = (days - 1) % 365
	var jm: int
	var jd: int
	if days < 186:
		jm = 1 + int(days / 31.0)
		jd = 1 + (days % 31)
	else:
		jm = 7 + int((days - 186) / 30.0)
		jd = 1 + ((days - 186) % 30)
	return [jy, jm, jd]


static func today() -> Array:
	var d := Time.get_date_dict_from_system()
	return from_gregorian(d.year, d.month, d.day)


## "۳ مرداد ۱۴۰۵"
static func format(j: Array, with_year := true) -> String:
	var s := "%s %s" % [I18n.digits(j[2]), MONTHS[j[1] - 1]]
	if with_year:
		s += " " + I18n.digits(j[0])
	return s


static func format_today(with_year := true) -> String:
	return format(today(), with_year)


## Whole-days since 1970-01-01 for a date dict — used for repeat-free daily cycles.
static func day_number(date := {}) -> int:
	var d: Dictionary = date if not date.is_empty() else Time.get_date_dict_from_system()
	var unix := Time.get_unix_time_from_datetime_dict(
		{"year": d.year, "month": d.month, "day": d.day, "hour": 12, "minute": 0, "second": 0})
	return int(unix / 86400.0)


## Occasion key for today's date, or "" — drives seasonal fal messages.
static func occasion(j: Array = []) -> String:
	var t: Array = j if not j.is_empty() else today()
	if t[1] == 1 and t[2] <= 3:
		return "nowruz"          # نوروز
	if t[1] == 9 and t[2] == 30:
		return "yalda"           # شب یلدا (last night of autumn)
	return ""
