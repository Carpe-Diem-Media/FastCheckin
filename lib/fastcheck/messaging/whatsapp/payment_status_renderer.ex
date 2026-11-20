defmodule FastCheck.Messaging.WhatsApp.PaymentStatusRenderer do
  @moduledoc """
  Customer-safe copy for WhatsApp payment status handoffs.
  """

  alias FastCheck.Messaging.WhatsApp.MenuRenderer

  @spec payment_link_queued(String.t() | nil) :: String.t()
  def payment_link_queued("en") do
    with_navigation(
      "en",
      "Your order is ready for payment. We are sending your secure Paystack payment link now."
    )
  end

  def payment_link_queued(_language) do
    with_navigation(
      "af",
      "Jou bestelling is gereed vir betaling. Ons stuur nou jou veilige Paystack-betaalskakel."
    )
  end

  @spec missing_email(String.t() | nil) :: String.t()
  def missing_email("en") do
    with_navigation(
      "en",
      "Please send your email address so we can create your secure payment link."
    )
  end

  def missing_email(_language) do
    with_navigation(
      "af",
      "Stuur asseblief jou e-posadres sodat ons jou veilige betaalskakel kan skep."
    )
  end

  @spec payment_pending(String.t() | nil) :: String.t()
  def payment_pending("en") do
    with_navigation(
      "en",
      "We are checking your payment. Your ticket will be prepared once payment is safely confirmed."
    )
  end

  def payment_pending(_language) do
    with_navigation(
      "af",
      "Ons bevestig jou betaling. Jou kaartjie sal voorberei word sodra betaling veilig bevestig is."
    )
  end

  @spec ticket_preparing(String.t() | nil) :: String.t()
  def ticket_preparing("en") do
    with_navigation("en", "Payment received. Your ticket is being prepared.")
  end

  def ticket_preparing(_language) do
    with_navigation("af", "Betaling ontvang. Jou kaartjie word voorberei.")
  end

  @spec manual_review(String.t() | nil) :: String.t()
  def manual_review("en") do
    "Your order needs support review.\n0. Main menu\nHelp. Contact support"
  end

  def manual_review(_language) do
    "Jou bestelling benodig ondersteuning.\n0. Hoofkieslys\nHelp. Kontak ondersteuning"
  end

  @spec terminal(String.t() | nil, String.t() | nil) :: String.t()
  def terminal("en", status) do
    with_navigation(
      "en",
      "This order is #{status || "not active"}. Please contact the event organiser if you need help."
    )
  end

  def terminal(_language, status) do
    with_navigation(
      "af",
      "Hierdie bestelling is #{status || "nie aktief nie"}. Kontak asseblief die geleentheidsorganiseerder vir hulp."
    )
  end

  defp with_navigation(language, body),
    do: body <> "\n\n" <> MenuRenderer.status_navigation(language)
end
