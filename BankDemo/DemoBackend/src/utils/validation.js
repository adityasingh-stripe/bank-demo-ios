/**
 * Validate individual profile data
 * @param {object} profileData - The profile data to validate
 * @returns {object} - Validation result with isValid and errors
 */
function validateIndividualProfile(profileData) {
  const errors = [];
  const requiredFields = ["firstName", "lastName", "email"];

  for (const field of requiredFields) {
    if (
      !profileData[field] ||
      typeof profileData[field] !== "string" ||
      profileData[field].trim() === ""
    ) {
      errors.push(`${field} is required and must be a non-empty string`);
    }
  }

  // Validate email format (basic)
  if (
    profileData.email &&
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(profileData.email)
  ) {
    errors.push("Email must be a valid email address");
  }

  // Validate phone format if provided
  if (profileData.phone && !/^\+[\d\s\-()]+$/.test(profileData.phone)) {
    errors.push(
      "Phone must be a valid international phone number starting with +"
    );
  }

  // Validate date of birth if provided
  if (profileData.dob) {
    const { day, month, year } = profileData.dob;
    if (
      !day ||
      !month ||
      !year ||
      day < 1 ||
      day > 31 ||
      month < 1 ||
      month > 12 ||
      year < 1900 ||
      year > new Date().getFullYear()
    ) {
      errors.push(
        "Date of birth must have valid day (1-31), month (1-12), and year"
      );
    }
  }

  // Validate address if provided
  if (profileData.address) {
    if (
      !profileData.address.line1 ||
      !profileData.address.city ||
      !profileData.address.country
    ) {
      errors.push("Address must include line1, city, and country");
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

/**
 * Validate company profile data
 * @param {object} profileData - The profile data to validate
 * @returns {object} - Validation result with isValid and errors
 */
function validateCompanyProfile(profileData) {
  const errors = [];
  const requiredFields = ["name"];

  for (const field of requiredFields) {
    if (
      !profileData[field] ||
      typeof profileData[field] !== "string" ||
      profileData[field].trim() === ""
    ) {
      errors.push(`${field} is required and must be a non-empty string`);
    }
  }

  // Validate email format if provided
  if (
    profileData.email &&
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(profileData.email)
  ) {
    errors.push("Email must be a valid email address");
  }

  // Validate phone format if provided
  if (profileData.phone && !/^\+[\d\s\-()]+$/.test(profileData.phone)) {
    errors.push(
      "Phone must be a valid international phone number starting with +"
    );
  }

  // Validate address if provided
  if (profileData.address) {
    if (
      !profileData.address.line1 ||
      !profileData.address.city ||
      !profileData.address.country
    ) {
      errors.push("Address must include line1, city, and country");
    }
  }

  // Validate MCC if provided
  if (profileData.mcc && !/^\d{4}$/.test(profileData.mcc)) {
    errors.push("MCC must be a 4-digit number");
  }

  // Validate URL if provided
  if (profileData.url && !/^https?:\/\/.+\..+/.test(profileData.url)) {
    errors.push("URL must be a valid HTTP or HTTPS URL");
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

/**
 * Validate business profile data
 * @param {object} businessProfile - The business profile data to validate
 * @returns {object} - Validation result with isValid and errors
 */
function validateBusinessProfile(businessProfile) {
  const errors = [];

  // Validate MCC if provided
  if (businessProfile.mcc && !/^\d{4}$/.test(businessProfile.mcc)) {
    errors.push("MCC must be a 4-digit number");
  }

  // Validate URL if provided
  if (businessProfile.url && !/^https?:\/\/.+\..+/.test(businessProfile.url)) {
    errors.push("URL must be a valid HTTP or HTTPS URL");
  }

  // Validate support phone if provided
  if (
    businessProfile.support_phone &&
    !/^\+[\d\s\-()]+$/.test(businessProfile.support_phone)
  ) {
    errors.push(
      "Support phone must be a valid international phone number starting with +"
    );
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

/**
 * Validate profile type
 * @param {string} profileType - The profile type to validate
 * @returns {boolean} - Whether the profile type is valid
 */
function isValidProfileType(profileType) {
  return ["individual", "company"].includes(profileType);
}

module.exports = {
  validateIndividualProfile,
  validateCompanyProfile,
  validateBusinessProfile,
  isValidProfileType,
};
