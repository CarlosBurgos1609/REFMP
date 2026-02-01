-- Edge Function to cleanup old guest users
-- Deploy this as a Supabase Edge Function and schedule it to run daily

-- Create this file in your Supabase project:
-- supabase/functions/cleanup-guests/index.ts

/*
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Call the database function to delete old guests
    const { error } = await supabaseClient.rpc('delete_old_guests')

    if (error) throw error

    return new Response(
      JSON.stringify({ message: 'Old guests cleaned up successfully' }),
      { headers: { "Content-Type": "application/json" }, status: 200 }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { "Content-Type": "application/json" }, status: 400 }
    )
  }
})
*/

-- To deploy this Edge Function:
-- 1. Install Supabase CLI: npm install -g supabase
-- 2. Login: supabase login
-- 3. Link your project: supabase link --project-ref your-project-ref
-- 4. Create the function: supabase functions new cleanup-guests
-- 5. Copy the code above into supabase/functions/cleanup-guests/index.ts
-- 6. Deploy: supabase functions deploy cleanup-guests
-- 7. Schedule it to run daily using Supabase Dashboard > Database > Cron Jobs
--    or use pg_cron if available

-- Alternative: Manual cleanup SQL query
-- Run this query periodically (daily) to clean up old guests:
-- SELECT delete_old_guests();

-- Or set up a pg_cron job (if pg_cron extension is available):
-- SELECT cron.schedule('delete-old-guests', '0 2 * * *', 'SELECT delete_old_guests();');
-- This runs at 2 AM every day

COMMENT ON SCHEMA public IS 'Use Edge Function or pg_cron to schedule automatic guest cleanup';
