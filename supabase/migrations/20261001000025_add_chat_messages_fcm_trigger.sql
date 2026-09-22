-- Attach FCM push notification trigger to chat_messages table
DROP TRIGGER IF EXISTS on_chat_message_created ON public.chat_messages;

CREATE TRIGGER on_chat_message_created
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_send_fcm_notification();
