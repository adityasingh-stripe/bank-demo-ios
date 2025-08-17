const stripe = require("../config/stripe");
const {
  INDIVIDUAL_PROFILES,
  COMPANY_PROFILES,
} = require("../config/constants");
const profileGenerator = require("./profileGenerator");

// Helper function to build base account configuration
function buildBaseAccountConfig() {
  return {
    capabilities: {
      card_payments: {
        requested: true,
      },
      transfers: {
        requested: true,
      },
    },
    country: "GB",
    controller: {
      fees: {
        payer: "application", // account | application
      },
      losses: {
        payments: "stripe", // application | stripe
      },
      requirement_collection: "stripe", // application | stripe
      stripe_dashboard: {
        type: "none", // express | full | none
      },
    },
    additional_verifications: {
      document: {
        apply_to: ["representative"],
        requested: true,
        require_live_capture: true,
        require_matching_selfie: true,
        upfront: [
          {
            disables: "payouts_and_payments",
          },
        ],
      },
    },
    settings: {
      payouts: {
        schedule: {
          interval: "daily",
        },
      },
    },
  };
}

// Helper function to build individual account configuration
function buildIndividualAccountConfig(profileData, businessProfile = {}) {
  const config = buildBaseAccountConfig();

  config.business_type = "individual";

  // Individual details
  config.individual = {
    first_name: profileData.firstName,
    last_name: profileData.lastName,
    email: profileData.email,
    phone: profileData.phone,
    dob: profileData.dob,
    address: profileData.address,
  };

  // Business profile
  config.business_profile = {
    name:
      profileData.businessName ||
      `${profileData.firstName} ${profileData.lastName}`,
    product_description:
      businessProfile.product_description ||
      profileData.product_description ||
      "",
    support_phone: businessProfile.support_phone || profileData.phone || "",
    mcc: businessProfile.mcc || "5999", // Default to misc retail
    url: profileData.website || businessProfile.url,
  };

  // External bank account
  config.external_account = {
    object: "bank_account",
    account_number: "00012345",
    routing_number: "108800",
    country: "GB",
    currency: "gbp",
    account_holder_name: `${profileData.firstName} ${profileData.lastName}`,
    account_holder_type: "individual",
  };

  return config;
}

// Helper function to build company account configuration
function buildCompanyAccountConfig(profileData, businessProfile = {}) {
  const config = buildBaseAccountConfig();

  config.business_type = "company";

  // Company details
  config.company = {
    name: profileData.name,
    address: profileData.address,
    phone: profileData.phone,
    tax_id: profileData.tax_id,
  };

  // Business profile
  config.business_profile = {
    name: profileData.name,
    product_description:
      businessProfile.product_description ||
      profileData.product_description ||
      "",
    support_phone: businessProfile.support_phone || profileData.phone || "",
    mcc: profileData.mcc || businessProfile.mcc || "5999", // Default to misc retail
    url: profileData.url || businessProfile.url,
  };

  // External bank account
  config.external_account = {
    object: "bank_account",
    account_number: "00012345",
    routing_number: "108800",
    country: "GB",
    currency: "gbp",
    account_holder_name: profileData.name,
    account_holder_type: "company",
  };

  return config;
}

/**
 * Create a connected account with the provided configuration
 * @param {string} profileType - 'individual' or 'company'
 * @param {object} profileData - Profile data for the account
 * @param {object} businessProfile - Business profile data
 * @returns {Promise<object>} - Created account object
 */
async function createConnectedAccount(
  profileType,
  profileData,
  businessProfile = {}
) {
  let accountConfig;

  if (profileType === "individual") {
    accountConfig = buildIndividualAccountConfig(profileData, businessProfile);
  } else {
    accountConfig = buildCompanyAccountConfig(profileData, businessProfile);
  }

  const account = await stripe.accounts.create(accountConfig);
  return account;
}

/**
 * Create persons (representatives/owners) for a company account
 */
async function createAccountPersons(accountId, representatives) {
  if (
    !representatives ||
    !Array.isArray(representatives) ||
    representatives.length === 0
  ) {
    return [];
  }

  const createdPersons = [];

  for (const rep of representatives) {
    try {
      const person = await stripe.accounts.createPerson(accountId, {
        first_name: rep.firstName,
        last_name: rep.lastName,
        email: rep.email,
        phone: rep.phone,
        dob: rep.dob,
        address: rep.address,
        relationship: rep.relationship,
      });

      createdPersons.push(person);
    } catch (error) {
      console.error(
        `Failed to create person for account ${accountId}:`,
        error.message
      );
    }
  }

  return createdPersons;
}

/**
 * Get demo profiles for profile selection
 * @param {object} options - Options for profile generation
 * @param {boolean} options.useHardcoded - Whether to use hardcoded profiles (for backwards compatibility)
 * @returns {object} - Demo profiles for individual and company
 */
function getDemoProfiles(options = {}) {
  if (options.useHardcoded) {
    // Fallback to hardcoded profiles if requested
    const { randomSelection } = require("../config/constants");
    const selectedIndividual = randomSelection(INDIVIDUAL_PROFILES);
    const selectedCompany = randomSelection(COMPANY_PROFILES);

    return {
      individual: {
        id: "individual_profile",
        type: "individual",
        name: `${selectedIndividual.firstName} ${selectedIndividual.lastName}`,
        businessName: selectedIndividual.businessName,
        email: selectedIndividual.email,
        phone: selectedIndividual.phone,
        address: selectedIndividual.address,
        profileData: selectedIndividual,
      },
      company: {
        id: "company_profile",
        type: "company",
        name: selectedCompany.name,
        email: selectedCompany.email,
        phone: selectedCompany.phone,
        address: selectedCompany.address,
        representative: selectedCompany.representative,
        profileData: selectedCompany,
      },
    };
  }

  // Generate fresh profiles each time instead of using hardcoded ones
  const generatedIndividual = profileGenerator.generateIndividualProfile();
  const generatedCompany = profileGenerator.generateCompanyProfile();

  return {
    individual: {
      id: "individual_profile",
      type: "individual",
      name: `${generatedIndividual.firstName} ${generatedIndividual.lastName}`,
      businessName: generatedIndividual.businessName,
      email: generatedIndividual.email,
      phone: generatedIndividual.phone,
      address: generatedIndividual.address,
      profileData: generatedIndividual,
    },
    company: {
      id: "company_profile",
      type: "company",
      name: generatedCompany.name,
      email: generatedCompany.email,
      phone: generatedCompany.phone,
      address: generatedCompany.address,
      representative: generatedCompany.representative,
      profileData: generatedCompany,
    },
  };
}

/**
 * Generate multiple profiles of a specific type
 * @param {string} type - 'individual' or 'company'
 * @param {number} count - Number of profiles to generate
 * @returns {Array} - Array of generated profiles
 */
function generateMultipleProfiles(type, count = 5) {
  return profileGenerator.generateProfiles(count, type);
}

/**
 * Create account session for embedded components
 */
async function createAccountSession(accountId) {
  const account = await stripe.accounts.retrieve(accountId);

  const session = await stripe.accountSessions.create({
    account: accountId,
    components: {
      payments: {
        enabled: true,
        features: {
          refund_management: true,
          dispute_management: true,
          capture_payments: true,
        },
      },
      account_onboarding: {
        enabled: true,
      },
      payouts: {
        enabled: true,
        features: {
          instant_payouts: true,
          edit_payout_schedule: false,
          external_account_collection: true,
        },
      },
      documents: {
        enabled: true,
      },
    },
  });

  return session;
}

module.exports = {
  createConnectedAccount,
  getDemoProfiles,
  generateMultipleProfiles,
  createAccountSession,
  buildIndividualAccountConfig,
  buildCompanyAccountConfig,
  createAccountPersons,
};
