export function getBoolean(key, defaultValue) {
	const value = localStorage.getItem(key);

	if (value === undefined || value === null) {
		return defaultValue;
	} else if (parseInt(value) === 0) {
		return false;
	} else if (parseInt(value) === 1) {
		return true;
	} else {
		throw Error(`Unexpected value (${value}) for key ${key}. Was this value set with setBoolean()?`)
	}
}

export function setBoolean(key, value) {
	if (value === true) {
		localStorage.setItem(key, "1");
	} else if (value === false) {
		localStorage.setItem(key, "0");
	} else {
		throw Error(`Non-boolean value (${value}) passed to setBoolean for key ${key}`)
	}
}