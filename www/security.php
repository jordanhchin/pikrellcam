<?php
// Request and input checks shared by the PiKrellCam web pages.

// Reject requests that a different web site made the browser send
// (cross-site request forgery).  Modern browsers send Sec-Fetch-Site,
// which is computed by the browser and so is not affected by a reverse
// proxy rewriting the Host header.  Older browsers fall back to
// comparing the Origin or Referer host.  Requests with none of these
// headers (curl, scripts) are allowed since they are not CSRF.
//
function pkc_same_origin()
	{
	if (isset($_SERVER['HTTP_SEC_FETCH_SITE']))
		{
		$site = $_SERVER['HTTP_SEC_FETCH_SITE'];
		return ($site === "same-origin" || $site === "none");
		}

	if (isset($_SERVER['HTTP_ORIGIN']))
		$url = $_SERVER['HTTP_ORIGIN'];
	else if (isset($_SERVER['HTTP_REFERER']))
		$url = $_SERVER['HTTP_REFERER'];
	else
		return true;

	$src = parse_url($url, PHP_URL_HOST);
	if (isset($_SERVER['HTTP_X_FORWARDED_HOST']))
		$host = $_SERVER['HTTP_X_FORWARDED_HOST'];
	else if (isset($_SERVER['HTTP_HOST']))
		$host = $_SERVER['HTTP_HOST'];
	else
		return false;
	$host = trim(explode(",", $host)[0]);
	$host = preg_replace('/:\d+$/', '', $host);
	$host = trim($host, "[]");

	return ($src !== null && $src !== false && strcasecmp($src, $host) == 0);
	}

function pkc_require_same_origin()
	{
	if (!pkc_same_origin())
		{
		http_response_code(403);
		echo "Forbidden: cross-site request";
		exit(0);
		}
	}

function pkc_require_method($methods)
	{
	$method = isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : "";
	if (!in_array($method, $methods, true))
		{
		http_response_code(405);
		header("Allow: " . implode(", ", $methods));
		echo "Method not allowed";
		exit(0);
		}
	}

// A media file name: no directory parts, no leading dot.
//
function pkc_valid_name($name)
	{
	return is_string($name)
		&& preg_match('/^[A-Za-z0-9][A-Za-z0-9_.:+-]{0,200}$/', $name)
		&& strpos($name, "..") === false;
	}

function pkc_valid_ymd($ymd)
	{
	return is_string($ymd) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $ymd);
	}

function pkc_get_int($key, $default, $min, $max)
	{
	if (!isset($_GET[$key]) || !preg_match('/^\d{1,4}$/', $_GET[$key]))
		return $default;
	$n = intval($_GET[$key]);
	if ($n < $min || $n > $max)
		return $default;
	return $n;
	}

function pkc_get_choice($key, $choices, $default)
	{
	if (isset($_GET[$key]) && in_array($_GET[$key], $choices, true))
		return $_GET[$key];
	return $default;
	}

function pkc_html($s)
	{
	return htmlspecialchars("$s", ENT_QUOTES, "UTF-8");
	}

// True if $path resolves to a file inside one of the $bases directories.
//
function pkc_path_within($path, $bases)
	{
	$real = realpath($path);
	if ($real === false || !is_file($real))
		return false;
	foreach ($bases as $base)
		{
		$rbase = realpath($base);
		if ($rbase !== false && strpos($real, $rbase . "/") === 0)
			return true;
		}
	return false;
	}
?>
