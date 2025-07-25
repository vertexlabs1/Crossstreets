# CrossStreets

A native iOS app for managing parking, floor selection, and history, with Supabase backend integration and widget support.

## Features
- Park/unpark flow
- Floor selection and quick selection
- Parking history
- Notes and issue reporting
- Location services
- Supabase backend integration
- Performance monitoring
- Home screen widget

## Setup
1. **Clone the repository**
2. **Install dependencies**
   - For Python scripts: `pip install -r requirements.txt`
3. **Configure secrets**
   - Copy `CrossStreets/Info.plist.example` to `CrossStreets/Info.plist`
   - Add your Supabase API key to the `SupabaseAPIKey` field
4. **Open in Xcode and build**

## Security
- **Never commit real API keys or secrets to source control.**
- The real `Info.plist` is .gitignored; use the example file for onboarding.

## Python Scripts
- `create_app_icon.py` requires Pillow: `pip install Pillow`

## Testing
- Run unit and UI tests from Xcode.

## License
[Specify your license here] 