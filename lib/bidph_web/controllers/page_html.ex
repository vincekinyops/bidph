defmodule BidphWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use BidphWeb, :html

  embed_templates "page_html/*"

  @doc """
  Returns a map with :hours, :minutes, :seconds for time remaining until `end_at`.
  If already past, returns zeros.
  """
  def time_remaining(end_at) do
    now = DateTime.utc_now()
    if DateTime.compare(end_at, now) != :gt do
      %{hours: 0, minutes: 0, seconds: 0}
    else
      diff = DateTime.diff(end_at, now, :second)
      hours = div(diff, 3600)
      rem_after_h = rem(diff, 3600)
      minutes = div(rem_after_h, 60)
      seconds = rem(rem_after_h, 60)
      %{hours: hours, minutes: minutes, seconds: seconds}
    end
  end

  attr :listing, Bidph.Listings.Listing, required: true

  def featured_auction(assigns) do
    ~H"""
    <.link href={~p"/listings/#{@listing.id}"} class="block w-full">
      <% # Featured section: full-width gradient background %>
      <section
        class="w-full"
        style="background: linear-gradient(135deg, #111827 0%, #1F2937 50%, #111827 100%);"
      >
        <div class="mx-auto max-w-7xl px-6 py-10 lg:px-8 lg:py-14">
          <div class="grid items-center gap-10 lg:grid-cols-2">
            <% # Left: image %>
            <div class="relative aspect-[4/3] rounded-2xl bg-[#101622] shadow-2xl overflow-hidden lg:aspect-auto lg:min-h-[360px] lg:h-full">
              <div
                class="absolute -inset-6 rounded-[28px] opacity-70 blur-3xl"
                style="background: radial-gradient(60% 60% at 40% 40%, rgba(255,127,0,0.25) 0%, rgba(255,127,0,0.08) 40%, rgba(15,23,42,0) 70%);"
              ></div>
              <div
                class="absolute -inset-2 rounded-2xl opacity-60 blur-2xl"
                style="background: linear-gradient(135deg, rgba(56,189,248,0.25) 0%, rgba(59,130,246,0.15) 40%, rgba(15,23,42,0) 70%);"
              ></div>
              <img
                :if={@listing.image_urls != []}
                src={List.first(@listing.image_urls)}
                alt={@listing.title}
                class="absolute inset-0 h-full w-full object-cover"
              />
          <div :if={@listing.image_urls == []} class="flex h-full w-full items-center justify-center text-white/30">
            <.icon name="hero-photo" class="size-16" />
          </div>
              <div class="absolute left-3 top-3">
                <span class="inline-flex items-center gap-2 rounded-full px-3 py-1 text-xs font-semibold text-white" style="background-color: #16A34A;">
                  <span class="size-2 rounded-full bg-white"></span>
                  LIVE NOW
                </span>
              </div>
              <div class="absolute bottom-3 right-3 inline-flex items-center gap-1.5 rounded-full bg-white px-3 py-1.5 text-sm font-medium text-[#0F172A]">
                <.icon name="hero-eye" class="size-4" />
                {length(@listing.bids || [])} watching
              </div>
            </div>
            <% # Right: details — white/grey text on dark %>
            <div class="flex flex-col text-white">
              <div>
                <span class="inline-block rounded-full px-3 py-1 text-xs font-semibold" style="border: 1px solid #F59E0B; color: #F59E0B;">
                  Featured Auction
                </span>
                <h2 class="mt-3 text-3xl font-bold text-white">{@listing.title}</h2>
                <p class="mt-2 text-sm leading-relaxed" style="color: #CBD5E1;">
                  {@listing.description || "Rare collector's piece with original documentation. Swiss made, excellent condition."}
                </p>
              </div>
              <% # Current Bid & Ends In cards %>
              <div class="mt-6 grid grid-cols-2 gap-4">
                <div class="rounded-xl p-4" style="background-color: #2D3748;">
                  <p class="text-xs" style="color: #94A3B8;">Current Bid</p>
                  <p class="text-2xl font-bold" style="color: #F97316;">₱{Decimal.to_string(@listing.current_price)}</p>
                </div>
                <div class="rounded-xl p-4" style="background-color: #2D3748;">
                  <p class="text-xs" style="color: #94A3B8;">Ends In</p>
                  <% rem = time_remaining(@listing.end_at) %>
                  <div class="mt-2 flex gap-1.5">
                    <span class="rounded-md bg-[#E2E8F0] px-2 py-1 font-mono text-xs font-semibold text-[#0F172A]">{String.pad_leading(to_string(rem.hours), 2, "0")}h</span>
                    <span class="rounded-md bg-[#E2E8F0] px-2 py-1 font-mono text-xs font-semibold text-[#0F172A]">{String.pad_leading(to_string(rem.minutes), 2, "0")}m</span>
                    <span class="rounded-md bg-[#E2E8F0] px-2 py-1 font-mono text-xs font-semibold text-[#0F172A]">{String.pad_leading(to_string(rem.seconds), 2, "0")}s</span>
                  </div>
                </div>
              </div>
              <% # Bid input area (visual only — whole card is a link) %>
              <div class="mt-6 rounded-xl p-4" style="background-color: #2D3748;">
                <div class="flex gap-2">
                  <div class="h-10 flex-1 rounded-lg bg-white"></div>
                  <div class="h-10 flex-1 rounded-lg bg-white"></div>
                  <div class="h-10 flex-1 rounded-lg bg-white"></div>
                </div>
                <div class="mt-2 flex gap-2">
                  <div class="flex flex-1 items-center gap-2 rounded-lg bg-white px-3 py-2 text-gray-900">
                    <span class="text-gray-500">₱</span>
                    <span class="flex-1"></span>
                  </div>
                  <span class="inline-flex shrink-0 items-center justify-center rounded-lg px-5 py-2.5 text-sm font-semibold text-white" style="background-color: #F97316;">Place Bid</span>
                </div>
                <p class="mt-2 text-xs" style="color: #94A3B8;">Min bid: ₱{min_bid_display(@listing.current_price)}</p>
              </div>
              <% # Recent Bids %>
              <div :if={(@listing.bids || []) != []} class="mt-6">
                <div class="flex items-center justify-between">
                  <span class="flex items-center gap-2 text-sm font-semibold text-white">
                    <span class="text-[#94A3B8]"><.icon name="hero-gavel" class="size-4" /></span>
                    Recent Bids
                  </span>
                  <span class="text-sm font-semibold" style="color: #F97316;">View All &gt;</span>
                </div>
                <ul class="mt-3 space-y-2 text-sm">
                  <li
                    :for={bid <- (@listing.bids || []) |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime}) |> Enum.take(3)}
                    class="flex items-center justify-between rounded-xl px-4 py-2"
                    style="background-color: #2D3748;"
                  >
                    <span class="text-white">Bidder</span>
                    <span class="font-semibold" style="color: #F97316;">₱{Decimal.to_string(bid.amount)}</span>
                    <span style="color: #94A3B8;">{format_bid_ago(bid.inserted_at)}</span>
                  </li>
                </ul>
              </div>
              <p class="mt-4 flex items-center gap-2 text-xs" style="color: #94A3B8;">
                <.icon name="hero-shield-check" class="size-4 shrink-0" />
                Buyer Protection Guarantee • Authenticity Verified
              </p>
            </div>
          </div>
        </div>
      </section>
    </.link>
    """
  end

  defp min_bid_display(current_price) do
    current_price
    |> Decimal.add(500)
    |> Decimal.to_string()
  end

  defp format_bid_ago(inserted_at) do
    diff_sec = DateTime.diff(DateTime.utc_now(), inserted_at, :second)
    cond do
      diff_sec < 60 -> "just now"
      diff_sec < 3600 -> "#{div(diff_sec, 60)} mins ago"
      diff_sec < 86400 -> "#{div(diff_sec, 3600)} hours ago"
      true -> "#{div(diff_sec, 86400)} days ago"
    end
  end

  attr :listing, Bidph.Listings.Listing, required: true
  attr :index, :integer, required: true

  def listing_card(assigns) do
    ~H"""
    <.link href={~p"/listings/#{@listing.id}"} class="group block">
      <article class="overflow-hidden rounded-2xl border border-base-200 bg-base-100 shadow-sm transition-all duration-300 group-hover:-translate-y-1 group-hover:shadow-xl group-hover:border-[#F97316]/50">
        <div class="relative aspect-[4/3] bg-base-300 overflow-hidden">
          <img
            :if={@listing.image_urls != []}
            src={List.first(@listing.image_urls)}
            alt={@listing.title}
            class="h-full w-full object-cover transition-transform duration-300 group-hover:scale-[1.05]"
          />
          <div :if={@listing.image_urls == []} class="flex h-full w-full items-center justify-center text-base-content/30">
            <.icon name="hero-photo" class="size-12" />
          </div>
          <div class="absolute left-2 top-2 flex flex-wrap gap-1.5">
            <span class="badge badge-sm border-0 bg-success/90 text-success-content">LIVE</span>
            <span :if={@listing.category} class="badge badge-sm border-0 bg-base-content/20 text-base-100">
              {@listing.category}
            </span>
          </div>
          <span :if={@index == 0} class="absolute bottom-2 left-2 badge badge-warning badge-sm border border-warning/50">
            Ending Soon!
          </span>
        </div>
        <div class="p-4">
          <h4 class="line-clamp-2 font-semibold text-base-content">{@listing.title}</h4>
          <p class="mt-1 text-xs text-base-content/60">Current Bid</p>
          <p class="font-bold text-primary">₱{Decimal.to_string(@listing.current_price)}</p>
          <div class="mt-2 flex items-center gap-3 text-xs text-base-content/60">
            <span class="flex items-center gap-1">
              <.icon name="hero-user" class="size-3.5" />
              {length(@listing.bids || [])}
            </span>
            <span class="flex items-center gap-1">
              <.icon name="hero-gavel" class="size-3.5" />
              {length(@listing.bids || [])}
            </span>
          </div>
          <% remaining = time_remaining(@listing.end_at) %>
          <div class="mt-3 flex gap-1">
            <span class="rounded-md border border-base-300 px-2 py-0.5 font-mono text-xs">{String.pad_leading(to_string(remaining.hours), 2, "0")}h</span>
            <span class="rounded-md border border-base-300 px-2 py-0.5 font-mono text-xs">{String.pad_leading(to_string(remaining.minutes), 2, "0")}m</span>
            <span class="rounded-md border border-base-300 px-2 py-0.5 font-mono text-xs">{String.pad_leading(to_string(remaining.seconds), 2, "0")}s</span>
          </div>
        </div>
      </article>
    </.link>
    """
  end
end
