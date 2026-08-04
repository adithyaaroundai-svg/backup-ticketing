# Setup Instructions (No Middleware Architecture)

## 1. Database Setup (Supabase)
1.  Go to your [Supabase Dashboard](https://supabase.com/dashboard).
2.  Open the **SQL Editor**.
3.  **Run the Migration**: Copy the contents of `supabase/migrations/20250524000000_initial_schema.sql` and run it.
    *   This creates the tables, RLS policies, and the `create_ticket` RPC function.
4.  **Run the Seed**: Copy the contents of `supabase/seed.sql` and run it.
    *   This creates a test customer with API Key: `TEST_API_KEY_001`.

## 2. Tally Integration (TDL)
1.  Open **Tally Prime**.
2.  Go to **Help > TDL & Add-On > F4 (Manage Local TDLs)**.
3.  Add the file path to `tally/ticket_plugin.tdl`.
    *   e.g., `C:\Users\user\StudioProjects\ticketing_system\tally\ticket_plugin.tdl`
4.  Accept the screen.
5.  You should see "Support Tickets" in the **Gateway of Tally**.

### Important Note on TDL Security
*   The TDL file uses `x-tally-api-key` header to authenticate with Supabase.
*   Each customer should have a **unique** `api_key` inserted into the `customers` table in Supabase.
*   The `ticket_plugin.tdl` file must be updated with the specific customer's `ApiKey` before deployment.

## 3. Agent App (Flutter)
1.  Open the project in your IDE.
2.  Run `flutter pub get`.
3.  Run `flutter run -d windows` (or chrome/android).
4.  Log in with an authenticated user (create one in Supabase Auth > Users first).

## 4. Testing the Flow
1.  **Raise Ticket**: In Tally, go to Support Tickets > Raise Ticket. Fill in details and submit.
    *   This sends a POST request to `https://<project>.supabase.co/rest/v1/rpc/create_ticket`.
2.  **View Ticket**: Open the Flutter Agent App. You should see the new ticket in the list instantly (Realtime).
