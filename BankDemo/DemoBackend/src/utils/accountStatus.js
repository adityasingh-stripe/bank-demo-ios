// Account status derivation logic based on requirements
function deriveAccountStatus(account) {
  const requirements = account.requirements || {};
  const payoutsEnabled = account.payouts_enabled || false;
  const chargesEnabled = account.charges_enabled || false;

  // Check if account is rejected
  if (
    requirements.disabled_reason &&
    requirements.disabled_reason.includes("rejected")
  ) {
    return {
      status: "Rejected",
      description: "The platform or Stripe has rejected the merchant account",
      capabilities: {
        payouts_enabled: false,
        charges_enabled: false,
      },
      requirements: {
        currently_due: requirements.currently_due || [],
        eventually_due: requirements.eventually_due || [],
        past_due: requirements.past_due || [],
        pending_verification: requirements.pending_verification || [],
      },
    };
  }

  // Both payouts and charges enabled
  if (payoutsEnabled && chargesEnabled) {
    if (
      requirements.pending_verification &&
      requirements.pending_verification.length > 0
    ) {
      return {
        status: "Pending",
        badge: "Enabled",
        description:
          "The account is currently being reviewed by Stripe; payouts and charges are enabled",
        capabilities: {
          payouts_enabled: true,
          charges_enabled: true,
        },
        requirements: {
          currently_due: requirements.currently_due || [],
          eventually_due: requirements.eventually_due || [],
          past_due: requirements.past_due || [],
          pending_verification: requirements.pending_verification || [],
        },
      };
    } else if (
      !requirements.disabled_reason &&
      (!requirements.past_due || requirements.past_due.length === 0) &&
      (!requirements.currently_due || requirements.currently_due.length === 0)
    ) {
      return {
        status: "Enabled",
        description: "Account is in good standing",
        capabilities: {
          payouts_enabled: true,
          charges_enabled: true,
        },
        requirements: {
          currently_due: requirements.currently_due || [],
          eventually_due: requirements.eventually_due || [],
          past_due: requirements.past_due || [],
          pending_verification: requirements.pending_verification || [],
        },
      };
    } else {
      return {
        status: "Restricted",
        description:
          "The account has pay-ins or payouts disabled and requires additional information",
        capabilities: {
          payouts_enabled: payoutsEnabled,
          charges_enabled: chargesEnabled,
        },
        requirements: {
          currently_due: requirements.currently_due || [],
          eventually_due: requirements.eventually_due || [],
          past_due: requirements.past_due || [],
          pending_verification: requirements.pending_verification || [],
        },
      };
    }
  }
  // Only payouts enabled with currently due requirements
  else if (
    payoutsEnabled &&
    requirements.currently_due &&
    requirements.currently_due.length > 0
  ) {
    return {
      status: "Restricted Soon",
      description:
        "The merchant account has a due date for providing certain information",
      capabilities: {
        payouts_enabled: true,
        charges_enabled: false,
      },
      requirements: {
        currently_due: requirements.currently_due || [],
        eventually_due: requirements.eventually_due || [],
        past_due: requirements.past_due || [],
        pending_verification: requirements.pending_verification || [],
      },
    };
  }
  // Pending verification with disabled capabilities
  else if (
    requirements.pending_verification &&
    requirements.pending_verification.length > 0
  ) {
    return {
      status: "Pending",
      badge: "Disabled",
      description:
        "The account is currently being reviewed by Stripe; payouts and charges are disabled",
      capabilities: {
        payouts_enabled: false,
        charges_enabled: false,
      },
      requirements: {
        currently_due: requirements.currently_due || [],
        eventually_due: requirements.eventually_due || [],
        past_due: requirements.past_due || [],
        pending_verification: requirements.pending_verification || [],
      },
    };
  }
  // Default to restricted
  else {
    return {
      status: "Restricted",
      description:
        "The account has pay-ins or payouts disabled and requires additional information",
      capabilities: {
        payouts_enabled: payoutsEnabled,
        charges_enabled: chargesEnabled,
      },
      requirements: {
        currently_due: requirements.currently_due || [],
        eventually_due: requirements.eventually_due || [],
        past_due: requirements.past_due || [],
        pending_verification: requirements.pending_verification || [],
      },
    };
  }
}

module.exports = {
  deriveAccountStatus,
};
