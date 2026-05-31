const List<Map<String, dynamic>> POPULAR_LOCATIONS = [
  // ==================== INDIA (All States Major Cities) ====================
  // North India
  {"city": "Delhi", "country": "India", "lat": 28.7041, "lng": 77.1025},
  {"city": "Mumbai", "country": "India", "lat": 19.0760, "lng": 72.8777},
  {"city": "Jaipur", "country": "India", "lat": 26.9124, "lng": 75.7873},
  {"city": "Lucknow", "country": "India", "lat": 26.8467, "lng": 80.9462},
  {"city": "Agra", "country": "India", "lat": 27.1767, "lng": 78.0081},
  {"city": "Varanasi", "country": "India", "lat": 25.3176, "lng": 82.9739},
  {"city": "Kanpur", "country": "India", "lat": 26.4499, "lng": 80.3319},
  {"city": "Prayagraj", "country": "India", "lat": 25.4358, "lng": 81.8463},
  {"city": "Meerut", "country": "India", "lat": 28.9845, "lng": 77.7064},
  {"city": "Aligarh", "country": "India", "lat": 27.8974, "lng": 78.0880},
  {"city": "Chandigarh", "country": "India", "lat": 30.7333, "lng": 76.7794},
  {"city": "Amritsar", "country": "India", "lat": 31.6340, "lng": 74.8723},
  {"city": "Ludhiana", "country": "India", "lat": 30.9010, "lng": 75.8573},
  {"city": "Dehradun", "country": "India", "lat": 30.3165, "lng": 78.0322},
  {"city": "Shimla", "country": "India", "lat": 31.1048, "lng": 77.1734},
  {"city": "Srinagar", "country": "India", "lat": 34.0837, "lng": 74.7973},
  {"city": "Jammu", "country": "India", "lat": 32.7266, "lng": 74.8570},

  // West India
  {"city": "Ahmedabad", "country": "India", "lat": 23.0225, "lng": 72.5714},
  {"city": "Surat", "country": "India", "lat": 21.1702, "lng": 72.8311},
  {"city": "Vadodara", "country": "India", "lat": 22.3072, "lng": 73.1812},
  {"city": "Rajkot", "country": "India", "lat": 22.3039, "lng": 70.8022},
  {"city": "Pune", "country": "India", "lat": 18.5204, "lng": 73.8567},
  {"city": "Nashik", "country": "India", "lat": 19.9975, "lng": 73.7898},
  {"city": "Nagpur", "country": "India", "lat": 21.1458, "lng": 79.0882},
  {"city": "Indore", "country": "India", "lat": 22.7196, "lng": 75.8577},
  {"city": "Bhopal", "country": "India", "lat": 23.2599, "lng": 77.4126},
  {"city": "Gwalior", "country": "India", "lat": 26.2183, "lng": 78.1828},
  {"city": "Jodhpur", "country": "India", "lat": 26.2389, "lng": 73.0243},
  {"city": "Udaipur", "country": "India", "lat": 24.5854, "lng": 73.7125},
  {"city": "Panaji (Goa)", "country": "India", "lat": 15.4909, "lng": 73.8278},
  {
    "city": "Mumbai Suburbs",
    "country": "India",
    "lat": 19.0886,
    "lng": 72.8679
  },

  // South India
  {"city": "Bangalore", "country": "India", "lat": 12.9716, "lng": 77.5946},
  {"city": "Hyderabad", "country": "India", "lat": 17.3850, "lng": 78.4867},
  {"city": "Chennai", "country": "India", "lat": 13.0827, "lng": 80.2707},
  {"city": "Coimbatore", "country": "India", "lat": 11.0168, "lng": 76.9558},
  {"city": "Madurai", "country": "India", "lat": 9.9252, "lng": 78.1198},
  {
    "city": "Tiruchirappalli",
    "country": "India",
    "lat": 10.7905,
    "lng": 78.7047
  },
  {"city": "Visakhapatnam", "country": "India", "lat": 17.6868, "lng": 83.2185},
  {"city": "Vijayawada", "country": "India", "lat": 16.5062, "lng": 80.6480},
  {"city": "Kochi", "country": "India", "lat": 9.9312, "lng": 76.2673},
  {
    "city": "Thiruvananthapuram",
    "country": "India",
    "lat": 8.5241,
    "lng": 76.9366
  },
  {"city": "Kozhikode", "country": "India", "lat": 11.2588, "lng": 75.7804},
  {"city": "Mysore", "country": "India", "lat": 12.2958, "lng": 76.6394},
  {"city": "Mangalore", "country": "India", "lat": 12.9141, "lng": 74.8560},

  // East India
  {"city": "Kolkata", "country": "India", "lat": 22.5726, "lng": 88.3639},
  {"city": "Patna", "country": "India", "lat": 25.5941, "lng": 85.1376},
  {"city": "Bhubaneswar", "country": "India", "lat": 20.2961, "lng": 85.8245},
  {"city": "Ranchi", "country": "India", "lat": 23.3441, "lng": 85.3096},
  {"city": "Jamshedpur", "country": "India", "lat": 22.8046, "lng": 86.2029},
  {"city": "Dhanbad", "country": "India", "lat": 23.7957, "lng": 86.4304},
  {"city": "Siliguri", "country": "India", "lat": 26.7271, "lng": 88.3953},
  {"city": "Guwahati", "country": "India", "lat": 26.1445, "lng": 91.7362},
  {"city": "Imphal", "country": "India", "lat": 24.8170, "lng": 93.9368},
  {"city": "Agartala", "country": "India", "lat": 23.8315, "lng": 91.2868},
  {"city": "Aizawl", "country": "India", "lat": 23.7271, "lng": 92.7176},

  // Central India
  {"city": "Raipur", "country": "India", "lat": 21.2514, "lng": 81.6296},
  {"city": "Bilaspur", "country": "India", "lat": 22.0796, "lng": 82.1409},
  {"city": "Jabalpur", "country": "India", "lat": 23.1686, "lng": 79.9339},
  {"city": "Ujjain", "country": "India", "lat": 23.1765, "lng": 75.7885},

  // ==================== MIDDLE EAST & SOUTH ASIA ====================
  // Saudi Arabia
  {"city": "Mecca", "country": "Saudi Arabia", "lat": 21.4225, "lng": 39.8262},
  {"city": "Medina", "country": "Saudi Arabia", "lat": 24.5247, "lng": 39.5692},
  {"city": "Riyadh", "country": "Saudi Arabia", "lat": 24.7136, "lng": 46.6753},
  {"city": "Jeddah", "country": "Saudi Arabia", "lat": 21.5433, "lng": 39.1728},
  {"city": "Dammam", "country": "Saudi Arabia", "lat": 26.3927, "lng": 49.9777},

  // UAE
  {"city": "Dubai", "country": "UAE", "lat": 25.2048, "lng": 55.2708},
  {"city": "Abu Dhabi", "country": "UAE", "lat": 24.4539, "lng": 54.3773},
  {"city": "Sharjah", "country": "UAE", "lat": 25.3463, "lng": 55.4209},
  {"city": "Ajman", "country": "UAE", "lat": 25.4052, "lng": 55.5136},
  {"city": "Ras Al Khaimah", "country": "UAE", "lat": 25.7895, "lng": 55.9432},
  {"city": "Fujairah", "country": "UAE", "lat": 25.1288, "lng": 56.3265},

  // Other Middle East
  {"city": "Doha", "country": "Qatar", "lat": 25.2854, "lng": 51.5310},
  {"city": "Muscat", "country": "Oman", "lat": 23.5880, "lng": 58.3829},
  {"city": "Kuwait City", "country": "Kuwait", "lat": 29.3759, "lng": 47.9774},
  {"city": "Manama", "country": "Bahrain", "lat": 26.2285, "lng": 50.5860},
  {"city": "Tehran", "country": "Iran", "lat": 35.6892, "lng": 51.3890},
  {"city": "Baghdad", "country": "Iraq", "lat": 33.3152, "lng": 44.3661},
  {"city": "Amman", "country": "Jordan", "lat": 31.9454, "lng": 35.9284},
  {"city": "Beirut", "country": "Lebanon", "lat": 33.8938, "lng": 35.5018},

  // Pakistan
  {"city": "Karachi", "country": "Pakistan", "lat": 24.8607, "lng": 67.0011},
  {"city": "Lahore", "country": "Pakistan", "lat": 31.5204, "lng": 74.3587},
  {"city": "Islamabad", "country": "Pakistan", "lat": 33.6844, "lng": 73.0479},
  {"city": "Rawalpindi", "country": "Pakistan", "lat": 33.5651, "lng": 73.0169},
  {"city": "Faisalabad", "country": "Pakistan", "lat": 31.4504, "lng": 73.1350},
  {"city": "Multan", "country": "Pakistan", "lat": 30.1575, "lng": 71.5249},

  // Other South Asia
  {"city": "Dhaka", "country": "Bangladesh", "lat": 23.8103, "lng": 90.4125},
  {
    "city": "Chittagong",
    "country": "Bangladesh",
    "lat": 22.3569,
    "lng": 91.7832
  },
  {"city": "Colombo", "country": "Sri Lanka", "lat": 6.9271, "lng": 79.8612},
  {"city": "Kandy", "country": "Sri Lanka", "lat": 7.2906, "lng": 80.6337},
  {"city": "Kathmandu", "country": "Nepal", "lat": 27.7172, "lng": 85.3240},
  {"city": "Pokhara", "country": "Nepal", "lat": 28.2096, "lng": 83.9856},
  {"city": "Thimphu", "country": "Bhutan", "lat": 27.4712, "lng": 89.6339},
  {"city": "Male", "country": "Maldives", "lat": 4.1755, "lng": 73.5093},

  // ==================== EAST ASIA & PACIFIC ====================
  // China
  {"city": "Beijing", "country": "China", "lat": 39.9042, "lng": 116.4074},
  {"city": "Shanghai", "country": "China", "lat": 31.2304, "lng": 121.4737},
  {"city": "Guangzhou", "country": "China", "lat": 23.1291, "lng": 113.2644},
  {"city": "Shenzhen", "country": "China", "lat": 22.5431, "lng": 114.0579},
  {"city": "Chengdu", "country": "China", "lat": 30.5728, "lng": 104.0668},
  {"city": "Chongqing", "country": "China", "lat": 29.4316, "lng": 106.9123},
  {"city": "Hong Kong", "country": "China", "lat": 22.3193, "lng": 114.1694},
  {"city": "Macau", "country": "China", "lat": 22.1987, "lng": 113.5439},

  // Japan
  {"city": "Tokyo", "country": "Japan", "lat": 35.6762, "lng": 139.6503},
  {"city": "Osaka", "country": "Japan", "lat": 34.6937, "lng": 135.5023},
  {"city": "Kyoto", "country": "Japan", "lat": 35.0116, "lng": 135.7681},
  {"city": "Yokohama", "country": "Japan", "lat": 35.4437, "lng": 139.6380},
  {"city": "Nagoya", "country": "Japan", "lat": 35.1815, "lng": 136.9066},

  // Korea
  {"city": "Seoul", "country": "South Korea", "lat": 37.5665, "lng": 126.9780},
  {"city": "Busan", "country": "South Korea", "lat": 35.1796, "lng": 129.0756},
  {
    "city": "Incheon",
    "country": "South Korea",
    "lat": 37.4563,
    "lng": 126.7052
  },

  // Southeast Asia
  {"city": "Singapore", "country": "Singapore", "lat": 1.3521, "lng": 103.8198},
  {
    "city": "Kuala Lumpur",
    "country": "Malaysia",
    "lat": 3.1390,
    "lng": 101.6869
  },
  {"city": "Penang", "country": "Malaysia", "lat": 5.4141, "lng": 100.3288},
  {"city": "Jakarta", "country": "Indonesia", "lat": -6.2088, "lng": 106.8456},
  {
    "city": "Bali (Denpasar)",
    "country": "Indonesia",
    "lat": -8.6705,
    "lng": 115.2126
  },
  {"city": "Bangkok", "country": "Thailand", "lat": 13.7367, "lng": 100.5231},
  {"city": "Phuket", "country": "Thailand", "lat": 7.8804, "lng": 98.3923},
  {"city": "Chiang Mai", "country": "Thailand", "lat": 18.7883, "lng": 98.9853},
  {
    "city": "Ho Chi Minh City",
    "country": "Vietnam",
    "lat": 10.8231,
    "lng": 106.6297
  },
  {"city": "Hanoi", "country": "Vietnam", "lat": 21.0285, "lng": 105.8542},
  {"city": "Manila", "country": "Philippines", "lat": 14.5995, "lng": 120.9842},
  {
    "city": "Cebu City",
    "country": "Philippines",
    "lat": 10.3157,
    "lng": 123.8854
  },
  {"city": "Yangon", "country": "Myanmar", "lat": 16.8661, "lng": 96.1951},
  {
    "city": "Phnom Penh",
    "country": "Cambodia",
    "lat": 11.5564,
    "lng": 104.9282
  },

  // Australia & NZ
  {"city": "Sydney", "country": "Australia", "lat": -33.8688, "lng": 151.2093},
  {
    "city": "Melbourne",
    "country": "Australia",
    "lat": -37.8136,
    "lng": 144.9631
  },
  {
    "city": "Brisbane",
    "country": "Australia",
    "lat": -27.4698,
    "lng": 153.0251
  },
  {"city": "Perth", "country": "Australia", "lat": -31.9505, "lng": 115.8605},
  {
    "city": "Adelaide",
    "country": "Australia",
    "lat": -34.9285,
    "lng": 138.6007
  },
  {
    "city": "Auckland",
    "country": "New Zealand",
    "lat": -36.8485,
    "lng": 174.7633
  },
  {
    "city": "Wellington",
    "country": "New Zealand",
    "lat": -41.2866,
    "lng": 174.7756
  },

  // ==================== EUROPE ====================
  {"city": "London", "country": "UK", "lat": 51.5074, "lng": -0.1278},
  {"city": "Manchester", "country": "UK", "lat": 53.4808, "lng": -2.2426},
  {"city": "Birmingham", "country": "UK", "lat": 52.4862, "lng": -1.8904},
  {"city": "Paris", "country": "France", "lat": 48.8566, "lng": 2.3522},
  {"city": "Berlin", "country": "Germany", "lat": 52.5200, "lng": 13.4050},
  {"city": "Munich", "country": "Germany", "lat": 48.1351, "lng": 11.5820},
  {"city": "Frankfurt", "country": "Germany", "lat": 50.1109, "lng": 8.6821},
  {"city": "Madrid", "country": "Spain", "lat": 40.4168, "lng": -3.7038},
  {"city": "Barcelona", "country": "Spain", "lat": 41.3851, "lng": 2.1734},
  {"city": "Rome", "country": "Italy", "lat": 41.9028, "lng": 12.4964},
  {"city": "Milan", "country": "Italy", "lat": 45.4642, "lng": 9.1900},
  {"city": "Venice", "country": "Italy", "lat": 45.4408, "lng": 12.3155},
  {"city": "Istanbul", "country": "Turkey", "lat": 41.0082, "lng": 28.9784},
  {"city": "Ankara", "country": "Turkey", "lat": 39.9334, "lng": 32.8597},
  {"city": "Moscow", "country": "Russia", "lat": 55.7558, "lng": 37.6173},
  {
    "city": "Saint Petersburg",
    "country": "Russia",
    "lat": 59.9311,
    "lng": 30.3609
  },
  {
    "city": "Amsterdam",
    "country": "Netherlands",
    "lat": 52.3676,
    "lng": 4.9041
  },
  {
    "city": "Rotterdam",
    "country": "Netherlands",
    "lat": 51.9244,
    "lng": 4.4777
  },
  {"city": "Vienna", "country": "Austria", "lat": 48.2082, "lng": 16.3738},
  {"city": "Zurich", "country": "Switzerland", "lat": 47.3769, "lng": 8.5417},
  {"city": "Geneva", "country": "Switzerland", "lat": 46.2044, "lng": 6.1432},
  {"city": "Brussels", "country": "Belgium", "lat": 50.8503, "lng": 4.3517},
  {"city": "Stockholm", "country": "Sweden", "lat": 59.3293, "lng": 18.0686},
  {"city": "Copenhagen", "country": "Denmark", "lat": 55.6761, "lng": 12.5683},
  {"city": "Oslo", "country": "Norway", "lat": 59.9139, "lng": 10.7522},
  {"city": "Helsinki", "country": "Finland", "lat": 60.1699, "lng": 24.9384},
  {"city": "Dublin", "country": "Ireland", "lat": 53.3498, "lng": -6.2603},
  {"city": "Warsaw", "country": "Poland", "lat": 52.2297, "lng": 21.0122},
  {
    "city": "Prague",
    "country": "Czech Republic",
    "lat": 50.0755,
    "lng": 14.4378
  },
  {"city": "Budapest", "country": "Hungary", "lat": 47.4979, "lng": 19.0402},
  {"city": "Athens", "country": "Greece", "lat": 37.9838, "lng": 23.7275},
  {"city": "Lisbon", "country": "Portugal", "lat": 38.7223, "lng": -9.1393},

  // ==================== NORTH AMERICA ====================
  // USA
  {"city": "New York", "country": "USA", "lat": 40.7128, "lng": -74.0060},
  {"city": "Los Angeles", "country": "USA", "lat": 34.0522, "lng": -118.2437},
  {"city": "Chicago", "country": "USA", "lat": 41.8781, "lng": -87.6298},
  {"city": "Houston", "country": "USA", "lat": 29.7604, "lng": -95.3698},
  {"city": "Phoenix", "country": "USA", "lat": 33.4484, "lng": -112.0740},
  {"city": "Philadelphia", "country": "USA", "lat": 39.9526, "lng": -75.1652},
  {"city": "San Antonio", "country": "USA", "lat": 29.4241, "lng": -98.4936},
  {"city": "San Diego", "country": "USA", "lat": 32.7157, "lng": -117.1611},
  {"city": "Dallas", "country": "USA", "lat": 32.7767, "lng": -96.7970},
  {"city": "San Francisco", "country": "USA", "lat": 37.7749, "lng": -122.4194},
  {"city": "Seattle", "country": "USA", "lat": 47.6062, "lng": -122.3321},
  {"city": "Boston", "country": "USA", "lat": 42.3601, "lng": -71.0589},
  {"city": "Miami", "country": "USA", "lat": 25.7617, "lng": -80.1918},
  {"city": "Atlanta", "country": "USA", "lat": 33.7490, "lng": -84.3880},
  {"city": "Las Vegas", "country": "USA", "lat": 36.1699, "lng": -115.1398},
  {"city": "Denver", "country": "USA", "lat": 39.7392, "lng": -104.9903},
  {
    "city": "Washington D.C.",
    "country": "USA",
    "lat": 38.9072,
    "lng": -77.0369
  },

  // Canada
  {"city": "Toronto", "country": "Canada", "lat": 43.6532, "lng": -79.3832},
  {"city": "Vancouver", "country": "Canada", "lat": 49.2827, "lng": -123.1207},
  {"city": "Montreal", "country": "Canada", "lat": 45.5017, "lng": -73.5673},
  {"city": "Calgary", "country": "Canada", "lat": 51.0447, "lng": -114.0719},
  {"city": "Ottawa", "country": "Canada", "lat": 45.4215, "lng": -75.6972},

  // Mexico & Central America
  {"city": "Mexico City", "country": "Mexico", "lat": 19.4326, "lng": -99.1332},
  {"city": "Cancun", "country": "Mexico", "lat": 21.1619, "lng": -86.8515},
  {
    "city": "Guadalajara",
    "country": "Mexico",
    "lat": 20.6597,
    "lng": -103.3496
  },

  // ==================== SOUTH AMERICA ====================
  {"city": "São Paulo", "country": "Brazil", "lat": -23.5505, "lng": -46.6333},
  {
    "city": "Rio de Janeiro",
    "country": "Brazil",
    "lat": -22.9068,
    "lng": -43.1729
  },
  {"city": "Brasília", "country": "Brazil", "lat": -15.8267, "lng": -47.9218},
  {"city": "Salvador", "country": "Brazil", "lat": -12.9777, "lng": -38.5016},
  {
    "city": "Buenos Aires",
    "country": "Argentina",
    "lat": -34.6037,
    "lng": -58.3816
  },
  {"city": "Santiago", "country": "Chile", "lat": -33.4489, "lng": -70.6693},
  {"city": "Bogotá", "country": "Colombia", "lat": 4.7110, "lng": -74.0721},
  {"city": "Medellín", "country": "Colombia", "lat": 6.2442, "lng": -75.5812},
  {"city": "Lima", "country": "Peru", "lat": -12.0464, "lng": -77.0428},
  {"city": "Quito", "country": "Ecuador", "lat": -0.1807, "lng": -78.4678},
  {"city": "Caracas", "country": "Venezuela", "lat": 10.4806, "lng": -66.9036},
  {
    "city": "Montevideo",
    "country": "Uruguay",
    "lat": -34.9011,
    "lng": -56.1645
  },

  // ==================== AFRICA ====================
  // North Africa
  {"city": "Cairo", "country": "Egypt", "lat": 30.0444, "lng": 31.2357},
  {"city": "Alexandria", "country": "Egypt", "lat": 31.2001, "lng": 29.9187},
  {"city": "Casablanca", "country": "Morocco", "lat": 33.5731, "lng": -7.5898},
  {"city": "Marrakech", "country": "Morocco", "lat": 31.6295, "lng": -7.9811},
  {"city": "Tunis", "country": "Tunisia", "lat": 36.8065, "lng": 10.1815},
  {"city": "Algiers", "country": "Algeria", "lat": 36.7538, "lng": 3.0588},
  {"city": "Tripoli", "country": "Libya", "lat": 32.8872, "lng": 13.1913},

  // Sub-Saharan Africa
  {"city": "Lagos", "country": "Nigeria", "lat": 6.5244, "lng": 3.3792},
  {"city": "Abuja", "country": "Nigeria", "lat": 9.0765, "lng": 7.3986},
  {
    "city": "Johannesburg",
    "country": "South Africa",
    "lat": -26.2041,
    "lng": 28.0473
  },
  {
    "city": "Cape Town",
    "country": "South Africa",
    "lat": -33.9249,
    "lng": 18.4241
  },
  {
    "city": "Durban",
    "country": "South Africa",
    "lat": -29.8587,
    "lng": 31.0218
  },
  {
    "city": "Pretoria",
    "country": "South Africa",
    "lat": -25.7479,
    "lng": 28.2293
  },
  {"city": "Nairobi", "country": "Kenya", "lat": -1.2921, "lng": 36.8219},
  {"city": "Mombasa", "country": "Kenya", "lat": -4.0435, "lng": 39.6682},
  {"city": "Addis Ababa", "country": "Ethiopia", "lat": 9.0320, "lng": 38.7469},
  {"city": "Accra", "country": "Ghana", "lat": 5.6037, "lng": -0.1870},
  {"city": "Dakar", "country": "Senegal", "lat": 14.7167, "lng": -17.4677},
  {"city": "Khartoum", "country": "Sudan", "lat": 15.5007, "lng": 32.5599},
  {
    "city": "Dar es Salaam",
    "country": "Tanzania",
    "lat": -6.7924,
    "lng": 39.2083
  },
  {"city": "Luanda", "country": "Angola", "lat": -8.8390, "lng": 13.2894},
];
