// @ts-nocheck
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type NotificationRow = {
	id: number;
	title: string | null;
	message: string | null;
	icon: string | null;
	image: string | null;
	redirect_to: string | null;
};

type TokenRow = {
	token: string | null;
	user_id: string | null;
};

const corsHeaders = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
	if (req.method === 'OPTIONS') {
		return new Response('ok', { headers: corsHeaders });
	}

	try {
		const { notificationId } = await req.json();

		const parsedNotificationId = Number(notificationId);
		if (!Number.isInteger(parsedNotificationId) || parsedNotificationId <= 0) {
			return new Response(
				JSON.stringify({ error: 'notificationId invalido' }),
				{
					status: 400,
					headers: { ...corsHeaders, 'Content-Type': 'application/json' },
				},
			);
		}

		const supabaseUrl = Deno.env.get('SUPABASE_URL');
		const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
		const fcmServerKey = Deno.env.get('FCM_SERVER_KEY');

		if (!supabaseUrl || !serviceRoleKey || !fcmServerKey) {
			return new Response(
				JSON.stringify({
					error: 'Faltan secretos requeridos: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FCM_SERVER_KEY',
				}),
				{
					status: 500,
					headers: { ...corsHeaders, 'Content-Type': 'application/json' },
				},
			);
		}

		const supabase = createClient(supabaseUrl, serviceRoleKey, {
			auth: { persistSession: false },
		});

		const { data: notification, error: notificationError } = await supabase
			.from('notifications')
			.select('id, title, message, icon, image, redirect_to')
			.eq('id', parsedNotificationId)
			.single<NotificationRow>();

		if (notificationError || !notification) {
			return new Response(
				JSON.stringify({ error: 'Notificacion no encontrada', details: notificationError?.message }),
				{
					status: 404,
					headers: { ...corsHeaders, 'Content-Type': 'application/json' },
				},
			);
		}

		const { data: rawTokens, error: tokensError } = await supabase
			.from('fcm_tokens')
			.select('token, user_id')
			.not('token', 'is', null);

		if (tokensError) {
			return new Response(
				JSON.stringify({ error: 'No se pudieron cargar tokens FCM', details: tokensError.message }),
				{
					status: 500,
					headers: { ...corsHeaders, 'Content-Type': 'application/json' },
				},
			);
		}

		const tokensRows = (rawTokens ?? []) as TokenRow[];
		const validRows = tokensRows.filter((row) => row.token && row.user_id);

		if (validRows.length === 0) {
			return new Response(
				JSON.stringify({ sent: 0, insertedUserNotifications: 0, removedInvalidTokens: 0 }),
				{ headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
			);
		}

		const uniqueByToken = new Map<string, TokenRow>();
		for (const row of validRows) {
			uniqueByToken.set(row.token as string, row);
		}
		const uniqueRows = Array.from(uniqueByToken.values());

		const userNotifications = uniqueRows.map((row) => ({
			user_id: row.user_id,
			notification_id: parsedNotificationId,
			is_read: false,
			is_deleted: false,
			created_at: new Date().toISOString(),
		}));

		const { error: insertError } = await supabase
			.from('user_notifications')
			.insert(userNotifications);

		if (insertError) {
			console.error('Error insertando user_notifications:', insertError.message);
		}

		const invalidTokens: string[] = [];
		let sent = 0;

		for (const row of uniqueRows) {
			const token = row.token as string;
			const response = await fetch('https://fcm.googleapis.com/fcm/send', {
				method: 'POST',
				headers: {
					Authorization: `key=${fcmServerKey}`,
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({
					to: token,
					priority: 'high',
					notification: {
						title: notification.title ?? 'Nueva notificacion',
						body: notification.message ?? '',
						sound: 'default',
					},
					data: {
						notification_id: String(parsedNotificationId),
						redirect_to: notification.redirect_to ?? '/notifications',
						title: notification.title ?? 'Nueva notificacion',
						body: notification.message ?? '',
						icon: notification.icon ?? 'notifications',
						image: notification.image ?? '',
					},
				}),
			});

			const payload = await response.json().catch(() => null);

			if (response.ok && payload?.success === 1) {
				sent += 1;
				continue;
			}

			const errorCode = payload?.results?.[0]?.error as string | undefined;
			if (errorCode === 'InvalidRegistration' || errorCode === 'NotRegistered') {
				invalidTokens.push(token);
			}
		}

		if (invalidTokens.length > 0) {
			const { error: removeError } = await supabase
				.from('fcm_tokens')
				.delete()
				.in('token', invalidTokens);

			if (removeError) {
				console.error('Error eliminando tokens invalidos:', removeError.message);
			}
		}

		return new Response(
			JSON.stringify({
				sent,
				totalTargets: uniqueRows.length,
				insertedUserNotifications: userNotifications.length,
				removedInvalidTokens: invalidTokens.length,
			}),
			{ headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
		);
	} catch (error) {
		const message = error instanceof Error ? error.message : 'Error desconocido';
		return new Response(
			JSON.stringify({ error: 'Error interno enviando push', details: message }),
			{
				status: 500,
				headers: { ...corsHeaders, 'Content-Type': 'application/json' },
			},
		);
	}
});
