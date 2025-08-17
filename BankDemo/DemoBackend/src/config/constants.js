// Test data constants for payments
const NAMES = [
  { firstName: "Basil", lastName: "Fawlty" },
  { firstName: "Del", lastName: "Trotter" },
  { firstName: "Hyacinth", lastName: "Bucket" },
  { firstName: "Edmund", lastName: "Blackadder" },
  { firstName: "David", lastName: "Brent" },
  { firstName: "Arthur", lastName: "Daley" },
  { firstName: "Victor", lastName: "Meldrew" },
  { firstName: "Sherlock", lastName: "Holmes" },
  { firstName: "John", lastName: "Watson" },
  { firstName: "Jean-Luc", lastName: "Picard" },
  { firstName: "Tommy", lastName: "Shelby" },
  { firstName: "James", lastName: "Moriarty" },
  { firstName: "Rodney", lastName: "Trotter" },
  { firstName: "Patsy", lastName: "Stone" },
  { firstName: "Edina", lastName: "Monsoon" },
  { firstName: "Mark", lastName: "Corrigan" },
  { firstName: "Jeremy", lastName: "Usborne" },
  { firstName: "Graham", lastName: "Chapman" },
  { firstName: "Eric", lastName: "Idle" },
  { firstName: "John", lastName: "Cleese" },
  { firstName: "Michael", lastName: "Palin" },
  { firstName: "Terry", lastName: "Jones" },
  { firstName: "Terry", lastName: "Gilliam" },
];

// Profile data for demo users
const INDIVIDUAL_PROFILES = [
  {
    firstName: "James",
    lastName: "Bond",
    email: "james.bond@mi6.gov.uk",
    phone: "+447700900007",
    dob: { day: 11, month: 11, year: 1965 },
    address: {
      line1: "10 Downing Street",
      city: "London",
      postal_code: "SW1A 2AA",
      country: "GB",
    },
    businessName: "Bond Security Consulting",
    website: "https://bondsecurity.co.uk",
    product_description:
      "Premium security consulting and risk assessment services for high-profile individuals and corporations",
  },
  {
    firstName: "Hermione",
    lastName: "Granger",
    email: "hermione.granger@hogwarts.edu",
    phone: "+447700900123",
    dob: { day: 19, month: 9, year: 1980 },
    address: {
      line1: "221B Baker Street",
      city: "London",
      postal_code: "NW1 6XE",
      country: "GB",
    },
    businessName: "Granger Legal Services",
    website: "https://grangerlegal.com",
    product_description:
      "Expert legal advice and representation specializing in intellectual property and contract law",
  },
  {
    firstName: "Arthur",
    lastName: "Dent",
    email: "arthur.dent@earth.galaxy",
    phone: "+447700900042",
    dob: { day: 8, month: 3, year: 1975 },
    address: {
      line1: "1 Abbey Road",
      city: "London",
      postal_code: "NW8 9AY",
      country: "GB",
    },
    businessName: "Dent Radio Services",
    website: "https://dentradio.co.uk",
    product_description:
      "Professional radio broadcasting equipment sales, installation, and maintenance services",
  },
];

const COMPANY_PROFILES = [
  {
    name: "Fawlty Hotels Ltd",
    email: "info@fawltyhotels.co.uk",
    phone: "+441803558000",
    tax_id: "12345678",
    address: {
      line1: "123 High Street",
      city: "Torquay",
      postal_code: "TQ1 3AB",
      country: "GB",
    },
    representative: {
      firstName: "Basil",
      lastName: "Fawlty",
      email: "basil@fawltyhotels.co.uk",
      phone: "+441803558001",
      dob: { day: 12, month: 5, year: 1955 },
      address: {
        line1: "123 High Street",
        city: "Torquay",
        postal_code: "TQ1 3AB",
        country: "GB",
      },
      title: "CEO",
      relationship: {
        representative: true,
        director: true,
        executive: true,
        owner: true,
        percent_ownership: 30,
        title: "CEO",
      },
    },
    mcc: "7011", // Hotels and Motels
    url: "https://fawltyhotels.co.uk",
    product_description:
      "Luxury seaside hotel accommodation with exceptional service and gourmet dining experiences",
  },
  {
    name: "Wheezes Retail Ltd",
    email: "contact@wheezesretail.co.uk",
    phone: "+442071234567",
    tax_id: "12345678",
    address: {
      line1: "45 Oxford Street",
      city: "London",
      postal_code: "W1C 2DX",
      country: "GB",
    },
    representative: {
      firstName: "Fred",
      lastName: "Weasley",
      email: "fred@wheezesretail.co.uk",
      phone: "+442071234568",
      dob: { day: 1, month: 4, year: 1978 },
      address: {
        line1: "45 Oxford Street",
        city: "London",
        postal_code: "W1C 2DX",
        country: "GB",
      },
      title: "Director",
      relationship: {
        representative: true,
        director: true,
        executive: true,
        owner: true,
        percent_ownership: 25,
        title: "Director",
      },
    },
    mcc: "5999", // Miscellaneous Retail
    url: "https://wheezesretail.co.uk",
    product_description:
      "Magical novelty items, pranks, and jokes for all ages - bringing laughter to the wizarding world",
  },
  {
    name: "Galaxy Dining Ltd",
    email: "reservations@galaxydining.co.uk",
    phone: "+447700900999",
    tax_id: "12345678",
    address: {
      line1: "12 Covent Garden",
      city: "London",
      postal_code: "WC2E 9HQ",
      country: "GB",
    },
    representative: {
      firstName: "Zaphod",
      lastName: "Beeblebrox",
      email: "zaphod@galaxydining.co.uk",
      phone: "+447700900998",
      dob: { day: 1, month: 1, year: 1970 },
      address: {
        line1: "12 Covent Garden",
        city: "London",
        postal_code: "WC2E 9HQ",
        country: "GB",
      },
      title: "Managing Director",
      relationship: {
        representative: true,
        director: true,
        executive: true,
        owner: true,
        percent_ownership: 35,
        title: "Managing Director",
      },
    },
    mcc: "5812", // Eating and Drinking Places
    url: "https://galaxydining.co.uk",
    product_description:
      "Pan-galactic fine dining restaurant featuring exotic cuisines from across the universe",
  },
];

// Payment constants
const CARD_TOKENS = [
  "pm_card_gb",
  "pm_card_gb_debit",
  "pm_card_gb_mastercard",
  "pm_card_amex",
];

const DISPUTE_TOKEN = "pm_card_createDispute";
const BYPASS_BALANCE_TOKEN = "pm_card_bypassPending";
const TOP_UP_AMOUNT = 1000000;
const PAYOUT_AMOUNTS = [454545, 24785, 5295, 125000, 78900];

// Helper functions
const randomPrice = () => Math.floor(Math.random() * (50000 - 250 + 1) + 250);
const randomSelection = (list) => list[Math.floor(Math.random() * list.length)];

module.exports = {
  NAMES,
  INDIVIDUAL_PROFILES,
  COMPANY_PROFILES,
  CARD_TOKENS,
  DISPUTE_TOKEN,
  BYPASS_BALANCE_TOKEN,
  TOP_UP_AMOUNT,
  PAYOUT_AMOUNTS,
  randomPrice,
  randomSelection,
};
