/**
 * Profile Generator Service
 * Generates realistic customer profiles on the fly for demo purposes
 */

// Base data for generating realistic profiles
const FIRST_NAMES = [
  "James",
  "Mary",
  "Robert",
  "Patricia",
  "John",
  "Jennifer",
  "Michael",
  "Linda",
  "David",
  "Elizabeth",
  "William",
  "Barbara",
  "Richard",
  "Susan",
  "Joseph",
  "Jessica",
  "Thomas",
  "Sarah",
  "Christopher",
  "Karen",
  "Charles",
  "Nancy",
  "Daniel",
  "Lisa",
  "Matthew",
  "Betty",
  "Anthony",
  "Helen",
  "Mark",
  "Sandra",
  "Donald",
  "Donna",
  "Steven",
  "Carol",
  "Paul",
  "Ruth",
  "Andrew",
  "Sharon",
  "Joshua",
  "Michelle",
  "Kenneth",
  "Laura",
  "Kevin",
  "Sarah",
  "Brian",
  "Kimberly",
  "George",
  "Deborah",
  "Timothy",
  "Dorothy",
  "Ronald",
  "Lisa",
  "Jason",
  "Nancy",
  "Edward",
  "Karen",
];

const LAST_NAMES = [
  "Smith",
  "Johnson",
  "Williams",
  "Brown",
  "Jones",
  "Garcia",
  "Miller",
  "Davis",
  "Rodriguez",
  "Martinez",
  "Hernandez",
  "Lopez",
  "Gonzalez",
  "Wilson",
  "Anderson",
  "Thomas",
  "Taylor",
  "Moore",
  "Jackson",
  "Martin",
  "Lee",
  "Perez",
  "Thompson",
  "White",
  "Harris",
  "Sanchez",
  "Clark",
  "Ramirez",
  "Lewis",
  "Robinson",
  "Walker",
  "Young",
  "Allen",
  "King",
  "Wright",
  "Scott",
  "Torres",
  "Nguyen",
  "Hill",
  "Flores",
  "Green",
  "Adams",
  "Nelson",
  "Baker",
  "Hall",
  "Rivera",
  "Campbell",
  "Mitchell",
  "Carter",
  "Roberts",
  "Gomez",
  "Phillips",
  "Evans",
  "Turner",
  "Diaz",
  "Parker",
];

const BUSINESS_TYPES = [
  "Consulting",
  "Services",
  "Solutions",
  "Technologies",
  "Systems",
  "Group",
  "Associates",
  "Partners",
  "Enterprises",
  "Industries",
  "Corporation",
  "Company",
  "Agency",
  "Studio",
  "Workshop",
  "Collective",
  "Network",
  "Alliance",
];

const BUSINESS_DESCRIPTORS = [
  "Digital",
  "Creative",
  "Professional",
  "Strategic",
  "Innovative",
  "Global",
  "Premium",
  "Elite",
  "Advanced",
  "Modern",
  "Expert",
  "Specialized",
  "Integrated",
  "Dynamic",
  "Comprehensive",
  "Custom",
  "Smart",
  "Efficient",
];

const INDUSTRY_TYPES = [
  {
    name: "Technology",
    mcc: "5734",
    description: "Software development and IT services",
  },
  {
    name: "Marketing",
    mcc: "7311",
    description: "Digital marketing and advertising services",
  },
  {
    name: "Consulting",
    mcc: "7392",
    description: "Business and management consulting",
  },
  {
    name: "Design",
    mcc: "7399",
    description: "Graphic design and creative services",
  },
  {
    name: "Legal",
    mcc: "8111",
    description: "Legal services and representation",
  },
  {
    name: "Healthcare",
    mcc: "8011",
    description: "Healthcare and medical services",
  },
  {
    name: "Education",
    mcc: "8220",
    description: "Educational services and training",
  },
  {
    name: "Finance",
    mcc: "6211",
    description: "Financial planning and advisory services",
  },
  {
    name: "Real Estate",
    mcc: "6513",
    description: "Real estate services and property management",
  },
  { name: "Retail", mcc: "5999", description: "Retail sales and merchandise" },
];

const COMPANY_SUFFIXES = [
  "Ltd",
  "LLC",
  "Inc",
  "Corp",
  "Group",
  "Associates",
  "Partners",
];

const UK_CITIES = [
  { name: "London", postalPrefix: "SW", country: "GB" },
  { name: "Manchester", postalPrefix: "M", country: "GB" },
  { name: "Birmingham", postalPrefix: "B", country: "GB" },
  { name: "Leeds", postalPrefix: "LS", country: "GB" },
  { name: "Glasgow", postalPrefix: "G", country: "GB" },
  { name: "Liverpool", postalPrefix: "L", country: "GB" },
  { name: "Bristol", postalPrefix: "BS", country: "GB" },
  { name: "Edinburgh", postalPrefix: "EH", country: "GB" },
  { name: "Cardiff", postalPrefix: "CF", country: "GB" },
  { name: "Sheffield", postalPrefix: "S", country: "GB" },
];

const STREET_NAMES = [
  "High Street",
  "Church Lane",
  "Main Street",
  "Park Road",
  "Church Street",
  "Victoria Road",
  "Green Lane",
  "Manor Road",
  "Church Road",
  "Park Lane",
  "Victoria Street",
  "Queens Road",
  "New Road",
  "Grosvenor Road",
  "Kings Road",
  "Mill Lane",
  "Station Road",
  "York Road",
  "London Road",
  "Windsor Road",
];

/**
 * Generate a random selection from an array
 */
function randomSelection(array) {
  return array[Math.floor(Math.random() * array.length)];
}

/**
 * Generate a random number within a range
 */
function randomNumber(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

/**
 * Generate a random date of birth for adults (18-80 years old)
 */
function generateDateOfBirth() {
  const currentYear = new Date().getFullYear();
  const minAge = 18;
  const maxAge = 80;

  const year = currentYear - randomNumber(minAge, maxAge);
  const month = randomNumber(1, 12);
  const day = randomNumber(1, 28); // Use 28 to avoid issues with February

  return { day, month, year };
}

/**
 * Generate a random UK address
 */
function generateAddress() {
  const city = randomSelection(UK_CITIES);
  const streetNumber = randomNumber(1, 999);
  const streetName = randomSelection(STREET_NAMES);
  const postalCode = `${city.postalPrefix}${randomNumber(1, 99)} ${randomNumber(
    1,
    9
  )}${String.fromCharCode(
    65 + Math.floor(Math.random() * 26)
  )}${String.fromCharCode(65 + Math.floor(Math.random() * 26))}`;

  return {
    line1: `${streetNumber} ${streetName}`,
    city: city.name,
    postal_code: postalCode,
    country: city.country,
  };
}

/**
 * Generate a random phone number
 */
function generatePhoneNumber() {
  const areaCode = randomNumber(1000, 9999);
  const number = randomNumber(100000, 999999);
  return `+44${areaCode}${number}`;
}

/**
 * Generate a random email address
 */
function generateEmail(firstName, lastName, domain = null) {
  const domains = [
    "gmail.com",
    "yahoo.com",
    "outlook.com",
    "hotmail.com",
    "example.com",
  ];
  const selectedDomain = domain || randomSelection(domains);
  const username = `${firstName.toLowerCase()}.${lastName.toLowerCase()}`;
  return `${username}@${selectedDomain}`;
}

/**
 * Generate a business name
 */
function generateBusinessName(firstName, lastName) {
  const usePersonalName = Math.random() < 0.3; // 30% chance to use personal name

  if (usePersonalName) {
    const type = randomSelection(BUSINESS_TYPES);
    return `${firstName} ${lastName} ${type}`;
  } else {
    const descriptor = randomSelection(BUSINESS_DESCRIPTORS);
    const type = randomSelection(BUSINESS_TYPES);
    return `${descriptor} ${type}`;
  }
}

/**
 * Generate a company name
 */
function generateCompanyName() {
  const descriptor = randomSelection(BUSINESS_DESCRIPTORS);
  const industry = randomSelection(INDUSTRY_TYPES);
  const suffix = randomSelection(COMPANY_SUFFIXES);

  const patterns = [
    `${descriptor} ${industry.name} ${suffix}`,
    `${industry.name} ${descriptor} ${suffix}`,
    `${descriptor} ${suffix}`,
    `${industry.name} ${suffix}`,
  ];

  return randomSelection(patterns);
}

/**
 * Generate a website URL
 */
function generateWebsite(name) {
  const cleanName = name
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, "")
    .replace(/\s+/g, "")
    .substring(0, 20);
  return `https://${cleanName}.co.uk`;
}

/**
 * Generate an individual customer profile
 */
function generateIndividualProfile() {
  const firstName = randomSelection(FIRST_NAMES);
  const lastName = randomSelection(LAST_NAMES);
  const industry = randomSelection(INDUSTRY_TYPES);
  const address = generateAddress();
  const businessName = generateBusinessName(firstName, lastName);

  return {
    firstName,
    lastName,
    email: generateEmail(firstName, lastName),
    phone: generatePhoneNumber(),
    dob: generateDateOfBirth(),
    address,
    businessName,
    website: generateWebsite(businessName),
    product_description: `Professional ${industry.description.toLowerCase()} for businesses and individuals`,
  };
}

/**
 * Generate a company customer profile
 */
function generateCompanyProfile() {
  const companyName = generateCompanyName();
  const industry = randomSelection(INDUSTRY_TYPES);
  const address = generateAddress();

  const companyDomain =
    companyName
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, "")
      .replace(/\s+/g, "")
      .substring(0, 15) + ".co.uk";

  // Generate multiple representatives (1-3)
  const numRepresentatives = randomNumber(1, 3);
  const representatives = [];
  const usedNames = new Set();

  for (let i = 0; i < numRepresentatives; i++) {
    let repFirstName, repLastName, nameKey;

    // Ensure unique names
    do {
      repFirstName = randomSelection(FIRST_NAMES);
      repLastName = randomSelection(LAST_NAMES);
      nameKey = `${repFirstName}_${repLastName}`;
    } while (usedNames.has(nameKey));

    usedNames.add(nameKey);

    const titles = [
      "CEO",
      "Director",
      "Managing Director",
      "Founder",
      "CFO",
      "COO",
    ];
    const isMainRep = i === 0; // First representative is the main one

    representatives.push({
      firstName: repFirstName,
      lastName: repLastName,
      email: `${repFirstName.toLowerCase()}.${repLastName.toLowerCase()}@${companyDomain}`,
      phone: generatePhoneNumber(),
      dob: generateDateOfBirth(),
      address,
      title: randomSelection(titles),
      relationship: {
        representative: isMainRep, // Only first rep is the main representative
        director: true,
        executive: i < 2, // First 2 are executives
        owner: true,
        percent_ownership: isMainRep
          ? randomNumber(35, 65)
          : randomNumber(10, 30),
        title: isMainRep ? "Director" : "Owner",
      },
    });
  }

  return {
    name: companyName,
    email: `info@${companyDomain}`,
    phone: generatePhoneNumber(),
    tax_id: "12345678",
    address,
    representatives, // Use array instead of single representative
    representative: representatives[0], // Keep backward compatibility
    mcc: industry.mcc,
    url: `https://${companyDomain}`,
    product_description: `${industry.description} with focus on quality and customer satisfaction`,
  };
}

/**
 * Generate profiles based on type
 */
function generateProfile(type) {
  switch (type) {
    case "individual":
      return generateIndividualProfile();
    case "company":
      return generateCompanyProfile();
    default:
      throw new Error(
        'Invalid profile type. Must be "individual" or "company"'
      );
  }
}

/**
 * Generate multiple profiles
 */
function generateProfiles(count = 1, type = "individual") {
  const profiles = [];
  for (let i = 0; i < count; i++) {
    profiles.push(generateProfile(type));
  }
  return profiles;
}

module.exports = {
  generateProfile,
  generateProfiles,
  generateIndividualProfile,
  generateCompanyProfile,
};
