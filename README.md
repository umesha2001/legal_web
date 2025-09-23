# Legalweb App

![Legalweb Logo](https://github.com/chathuraz/legal_web/blob/master/assets/images/legal_web_1.png?raw=true) <!-- Replace with actual logo if available, e.g., from page 5 of the report -->

Your trusted legal partner, anytime, anywhere.

## Overview

Legalweb is an AI-powered mobile application designed to revolutionize access to legal services in Sri Lanka. It bridges the gap between ordinary users and legal professionals by providing a secure, efficient, and reliable platform. Users can find suitable lawyers based on experience, expertise, and ratings; schedule video consultations; make secure online payments; and get instant responses to simple legal queries via an AI chatbot.

This project was developed as part of the Capstone Project (IS 4110) for the BSc (Honors) in Information Systems at the Department of Computing and Information Systems, Faculty of Computing, Sabaragamuwa University of Sri Lanka.

The app aims to democratize legal services, reduce barriers like high costs and limited availability, and empower users with real-time legal support using modern technologies.

**Keywords:** Legalweb, Artificial Intelligence, AI Chatbot, Video Consultations

## Features

- **User Module:**
  - Register and create profiles.
  - Search and select lawyers based on expertise, experience, and user ratings.
  - Book video consultation sessions with available time slots.
  - Make secure online payments via integrated gateways.
  - Interact with an AI-powered chatbot for instant legal advice on common queries (based on Sri Lankan legal resources).
  - Upload case-related documents to lawyers.

- **Lawyer Module:**
  - Register and create detailed profiles (including work experience and specialties).
  - Manage availability and booking schedules.
  - Conduct video consultations and chat sessions with clients (e.g., sharing meeting links or documents).

- **Admin Module:**
  - Verify lawyer profiles for authenticity.
  - Manage user complaints and monitor platform operations.

- **AI Chatbot:**
  - Provides real-time responses to legal inquiries using Google Gemini API.
  - Supports basic legal guidance to keep users informed and reduce wait times.

- **Additional Capabilities:**
  - Secure authentication and data encryption.
  - Multi-device compatibility (Android and iOS via Flutter).
  - Future potential for crime awareness alerts (e.g., fraud detection from user complaints).

## Technologies Used

- **Frontend:** Flutter (Dart) for cross-platform mobile development.
- **Backend:** Firebase (including Realtime Database, Authentication, and Firestore for data storage).
- **AI Integration:** Google Gemini API for the chatbot's natural language processing.
- **Other Tools:**
  - Git for version control.
  - Visual Studio Code and Android Studio for development.
  - Jira for project management.

No additional packages can be installed beyond the pre-included libraries (e.g., no internet-dependent installs like pip).

## Installation and Setup

1. **Prerequisites:**
   - Flutter SDK (version compatible with the project, e.g., 3.x).
   - Android Studio or Xcode for emulators/simulators.
   - Firebase account (set up a project and download the `google-services.json` for Android or `GoogleService-Info.plist` for iOS).
   - Google Gemini API key (add to your environment or config files).

2. **Clone the Repository:**
   git clone https://github.com/chathuraz/legal_web.git
   cd legal_web

3. **Install Dependencies:**
   flutter pub get

4. **Configure Firebase:**
- Place your Firebase config files in the appropriate directories (e.g., `android/app/` for Android).
- Update API keys in the code (e.g., for Gemini in the chatbot module).

5. **Run the App:**
   flutter run

- For Android: Ensure an emulator or device is connected.
- For iOS: Use Xcode on macOS.

**Note:** The app assumes users have smartphones with internet access. Test on multiple devices for compatibility.

## Usage

1. **User Flow:**
- Sign up/login as a user.
- Describe your legal issue to get lawyer recommendations.
- Book a session, pay securely, and join the video consultation.
- Use the AI chatbot for quick queries (e.g., "What are my rights in a divorce case?").

2. **Lawyer Flow:**
- Sign up/login as a lawyer and complete your profile.
- Set availability and accept bookings.
- Conduct consultations via integrated video/chat.

3. **Admin Flow:**
- Access the admin panel to verify lawyers and handle complaints.

For detailed diagrams (ER, Use Case, Data Flow), refer to the project report in the repository (if uploaded) or Chapter 3 of the final report.

## Project Structure

- `/lib`: Main Flutter source code (UI, logic, models).
- `/assets`: Images, icons, and other resources.
- `/firebase`: Configuration files (add your own).
- Backend logic is handled via Firebase functions and API calls.

## Challenges and Limitations

- **Over-Ambitious Aims:** Features like real-time crime data analysis and legal document generation were planned but not fully implemented due to time constraints and lack of supporting APIs.
- **Chatbot Accuracy:** Achieved ~85% accuracy for common queries; complex cases may require human lawyers.
- **Language Support:** Currently English-only; future enhancements for Sinhala/Tamil.
- **Data Sources:** Relies on Firebase; no external scraping for legal news.

For more details, see Chapter 4 (Implementation) and Chapter 5 (Results and Evaluation) in the project report.

## Future Work

- Add multilingual support (Sinhala, Tamil).
- Integrate real-time legal news updates and crime trend analysis.
- Enhance AI chatbot with more training data.
- Add lawyer rating/reviews and document generation features.

See Chapter 6 for detailed proposals.

## Contributors

- **AWUI Withanage** (21CIS0140) - [GitHub Profile](https://github.com/IndWit) 
- **KHC Sajeewa** (21CIS0198) - [GitHub Profile](https://github.com/chathuraz)
- **EPAH Edirisinghe** (21CIS0206) - [GitHub Profile](https://github.com/Ashan-Edirisinghe)
- **SWKA Thathsarani** (21CIS0211) - [GitHub Profile](https://github.com/Samaranayaka29)
- **JAUU Jayakody** (21CIS0216) - [GitHub Profile](https://github.com/umesha2001)

**Supervisor:** W.T. Saranga Somaweera  
**Mentor:** Wimarshana Bandara  
**Coordinator:** Mrs. W.V.S.K. Wasalthilake  

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## References

- Project Report: [Capstone_Project_Mini_Project_final_report Group 24_250718_111746.pdf](path/to/report.pdf) <!-- Upload to repo if not already -->
- GitHub Repo: https://github.com/chathuraz/legal_web
- External: Flutter Docs, Firebase Docs, Google Gemini API.

For questions or contributions, open an issue or pull request!
