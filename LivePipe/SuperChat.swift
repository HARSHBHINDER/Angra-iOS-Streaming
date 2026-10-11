import Foundation
import UIKit

/// One paid message: a Super Chat or Super Sticker. `micros` = amount × 1,000,000 in `currency`.
struct SuperChat {
    var name: String
    var amount: String                  // as YouTube shows it, e.g. "$10.00", "₹500.00"
    var micros: Int64
    var currency: String
    var message: String
    var tier: Int                       // YouTube colour tier, 1 (lowest) ... 7
    var sticker = false
    var total: String? = nil            // this supporter's total this stream, when they've given more than once
    var avatar: UIImage? = nil

    static func sample(tier: Int = 4) -> SuperChat {
        let amounts = ["$1.00", "$2.00", "$5.00", "$10.00", "$20.00", "$50.00", "$100.00"]
        return SuperChat(name: "Alex Rivera", amount: amounts[min(max(tier, 1), 7) - 1], micros: 0, currency: "USD",
                         message: "Clutch play!! Keep the streams coming", tier: tier, total: "$25.00")
    }
}

/// Watches a YouTube live chat for Super Chats and Super Stickers through the official YouTube Data API v3,
/// using the streamer's own API key. `source` = a live video link/ID, a channel ID (UC…) or an @handle.
/// ponytail: polls at YouTube's own interval (at least 8 s), so the default 10k/day quota covers roughly 2–4 h
/// of live chat; longer streams need a quota increase on the user's Google Cloud project.
final class YouTubeChat: @unchecked Sendable {
    private let apiKey: String
    private let source: String
    private let onEvent: (SuperChat) -> Void
    private let onStatus: (String) -> Void
    private var task: Task<Void, Never>?

    init(apiKey: String, source: String, onEvent: @escaping (SuperChat) -> Void, onStatus: @escaping (String) -> Void) {
        self.apiKey = apiKey; self.source = source; self.onEvent = onEvent; self.onStatus = onStatus
        task = Task.detached { [self] in await run() }
    }

    func stop() { task?.cancel() }

    private struct ChatError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private func run() async {
        var chatId: String?
        var page: String?
        var first = true
        var totals: [String: Int64] = [:]              // author channel + currency -> micros this stream
        while !Task.isCancelled {
            do {
                if chatId == nil {
                    onStatus("Looking for your YouTube live stream…")
                    chatId = try await liveChatId()
                    if chatId == nil {
                        onStatus("Not live on YouTube yet. Checking again shortly.")
                        try await Task.sleep(nanoseconds: 45_000_000_000)
                        continue
                    }
                    onStatus("Connected. Watching live chat for Super Chats.")
                    page = nil; first = true
                }
                var path = "liveChat/messages?part=snippet,authorDetails&maxResults=200&liveChatId=\(Self.enc(chatId ?? ""))"
                if let page { path += "&pageToken=\(Self.enc(page))" }
                let r = try await get(path)
                page = (r["nextPageToken"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                // The first page is chat history from before we connected: skip it so old Super Chats don't replay.
                if !first {
                    for item in (r["items"] as? [[String: Any]]) ?? [] {
                        if let e = await parse(item, totals: &totals) { onEvent(e) }
                    }
                }
                first = false
                let wait = max((r["pollingIntervalMillis"] as? NSNumber)?.int64Value ?? 10_000, 8_000)
                try await Task.sleep(nanoseconds: UInt64(wait) * 1_000_000)
            } catch is CancellationError {
                return
            } catch {
                let msg = error.localizedDescription
                onStatus("YouTube: \(msg)")
                if msg.contains("ended") || msg.lowercased().contains("not found") { chatId = nil }   // stream ended or restarted
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
    }

    private func parse(_ item: [String: Any], totals: inout [String: Int64]) async -> SuperChat? {
        guard let sn = item["snippet"] as? [String: Any], let type = sn["type"] as? String else { return nil }
        let sticker: Bool
        switch type {
        case "superChatEvent": sticker = false
        case "superStickerEvent": sticker = true
        default: return nil
        }
        guard let det = sn[sticker ? "superStickerDetails" : "superChatDetails"] as? [String: Any] else { return nil }
        let author = item["authorDetails"] as? [String: Any]
        let micros = Int64((det["amountMicros"] as? String) ?? "") ?? 0
        let currency = det["currency"] as? String ?? ""
        let key = ((author?["channelId"] as? String) ?? "") + currency
        let sum = (totals[key] ?? 0) + micros
        totals[key] = sum
        var avatar: UIImage?
        if let s = author?["profileImageUrl"] as? String, let url = URL(string: s),
           let res = try? await URLSession.shared.data(from: url) {
            avatar = UIImage(data: res.0)
        }
        let message = sticker
            ? (((det["superStickerMetadata"] as? [String: Any])?["altText"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Super Sticker")
            : (det["userComment"] as? String ?? "")
        let name = (author?["displayName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Someone"
        return SuperChat(name: name, amount: det["amountDisplayString"] as? String ?? "", micros: micros, currency: currency,
                         message: message, tier: (det["tier"] as? NSNumber)?.intValue ?? 1, sticker: sticker,
                         total: sum > micros ? Self.money(sum, currency) : nil, avatar: avatar)
    }

    private func liveChatId() async throws -> String? {
        let src = Self.parse(source)
        var videoId = src.videoId
        if videoId == nil {
            var channel = src.channelId
            if channel == nil, let handle = src.handle {
                let r = try await get("channels?part=id&forHandle=\(Self.enc("@" + handle))")
                channel = ((r["items"] as? [[String: Any]])?.first)?["id"] as? String
            }
            guard let channel else { throw ChatError(message: "Enter your @handle, channel ID or live link") }
            let r = try await get("search?part=id&type=video&eventType=live&maxResults=1&channelId=\(Self.enc(channel))")
            videoId = (((r["items"] as? [[String: Any]])?.first)?["id"] as? [String: Any])?["videoId"] as? String
            if videoId == nil { return nil }
        }
        let r = try await get("videos?part=liveStreamingDetails&id=\(Self.enc(videoId ?? ""))")
        let details = ((r["items"] as? [[String: Any]])?.first)?["liveStreamingDetails"] as? [String: Any]
        return (details?["activeLiveChatId"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The API key goes in a header, not the URL, so it never lands in logs.
    private func get(_ path: String) async throws -> [String: Any] {
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/" + path) else { throw ChatError(message: "Bad request") }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let code = (resp as? HTTPURLResponse)?.statusCode, !(200..<300).contains(code) {
            throw ChatError(message: ((json["error"] as? [String: Any])?["message"] as? String) ?? "HTTP \(code)")
        }
        return json
    }

    // MARK: Helpers

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    private static func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s }

    /// What the streamer typed: a live/video link or ID, a channel ID, or an @handle (bare or in a URL).
    static func parse(_ s: String) -> (videoId: String?, channelId: String?, handle: String?) {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let v = first("(?:v=|youtu\\.be/|/live/|/shorts/)([A-Za-z0-9_-]{11})", in: t) { return (v, nil, nil) }
        if let c = first("(UC[A-Za-z0-9_-]{22})", in: t) { return (nil, c, nil) }
        if let h = first("@([A-Za-z0-9._-]{3,30})", in: t) { return (nil, nil, h) }
        if first("^([A-Za-z0-9_-]{11})$", in: t) != nil { return (t, nil, nil) }
        return (nil, nil, nil)
    }

    private static func first(_ pattern: String, in s: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }

    static func money(_ micros: Int64, _ currency: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        return f.string(from: NSNumber(value: Double(micros) / 1_000_000)) ?? String(format: "%.2f %@", Double(micros) / 1_000_000, currency)
    }
}

/// Draws the on-stream Super Chat card, identical to Android's SuperChatCard. The same image is used for the
/// stream and for every preview in the app. No app name or branding on any style.
enum SuperChatCard {
    static let styles = ["Ember", "Classic", "Minimal", "Neon"]

    // YouTube's Super Chat colours per tier: (deep, bright). Tier 1 is the lowest amount.
    private static let tiers: [(UInt32, UInt32)] = [
        (0x1565C0, 0x1E88E5), (0x00B8D4, 0x00E5FF), (0x00BFA5, 0x1DE9B6), (0xFFB300, 0xFFCA28),
        (0xE65100, 0xF57C00), (0xC2185B, 0xE91E63), (0xD00000, 0xE62117),
    ]
    private static let margin: CGFloat = 44           // room for the glow around the card

    static func deep(_ tier: Int) -> UIColor { rgb(tiers[min(max(tier, 1), 7) - 1].0) }
    static func bright(_ tier: Int) -> UIColor { rgb(tiers[min(max(tier, 1), 7) - 1].1) }
    private static func lightTier(_ tier: Int) -> Bool { (2...4).contains(tier) }   // cyan, green, yellow: dark text

    static func render(_ e: SuperChat, style: Int, showTotal: Bool) -> UIImage {
        switch style {
        case 1: return classic(e, showTotal)
        case 2: return minimal(e)
        case 3: return neon(e, showTotal)
        default: return ember(e, showTotal)
        }
    }

    // MARK: Ember — dark glass, tier-coloured glow and sheen, avatar ring, amount pill

    private static func ember(_ e: SuperChat, _ showTotal: Bool) -> UIImage {
        let w: CGFloat = 960, pad: CGFloat = 36, r: CGFloat = 48
        let msgFont = font(36), totalLine = showTotal ? e.total.map { "Total this stream  ·  \($0)" } : nil
        let msgH = e.message.isEmpty ? 0 : textHeight(e.message, msgFont, w - 2 * pad, 4)
        let h = pad + 2 * r + (msgH > 0 ? 26 + msgH : 0) + (totalLine != nil ? 66 : 0) + pad
        return card(w, h) { ctx, box in
            let shape = UIBezierPath(roundedRect: box, cornerRadius: 40)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 40, color: bright(e.tier).withAlphaComponent(0.55).cgColor)
            UIColor(white: 0.1, alpha: 0.96).setFill(); shape.fill()
            ctx.restoreGState()
            ctx.saveGState(); shape.addClip()
            gradient(ctx, [rgb(0x202024, 0.96), rgb(0x0C0C0E, 0.96)], from: CGPoint(x: 0, y: box.minY), to: CGPoint(x: 0, y: box.maxY))
            ctx.clip(to: CGRect(x: box.minX, y: box.minY, width: box.width, height: 9))
            gradient(ctx, [deep(e.tier), bright(e.tier)], from: CGPoint(x: box.minX, y: 0), to: CGPoint(x: box.maxX, y: 0))
            ctx.restoreGState()
            UIColor(white: 1, alpha: 0.15).setStroke(); shape.lineWidth = 2; shape.stroke()

            let left = box.minX + pad, top = box.minY + pad
            avatar(e, center: CGPoint(x: left + r, y: top + r), r: r, ring: bright(e.tier))
            let tx = left + 2 * r + 26
            let tag = e.sticker ? "SUPER STICKER" : "SUPER CHAT"
            let tagFont = font(22, .bold)
            let tagW = (tag as NSString).size(withAttributes: [.font: tagFont, .kern: 3]).width
            draw(tag, tagFont, bright(e.tier), CGRect(x: box.maxX - pad - tagW, y: top + 4, width: tagW + 4, height: 30), kern: 3)
            draw(e.name, font(40, .medium), .white, CGRect(x: tx, y: top - 2, width: box.maxX - pad - tx - tagW - 20, height: 50))
            pill(e.amount, x: tx, y: top + 54, h: 46, fill: bright(e.tier), fg: lightTier(e.tier) ? UIColor(white: 0, alpha: 0.9) : .white, font: font(32, .bold))
            var y = top + 2 * r
            if msgH > 0 {
                y += 26
                draw(e.message, msgFont, UIColor(white: 1, alpha: 0.92), CGRect(x: left, y: y, width: w - 2 * pad, height: msgH), lines: 4)
                y += msgH
            }
            if let totalLine {
                y += 22
                UIColor(white: 1, alpha: 0.12).setFill(); UIRectFill(CGRect(x: left, y: y, width: w - 2 * pad, height: 2))
                draw(totalLine, font(26, .medium), UIColor(white: 1, alpha: 0.65), CGRect(x: left, y: y + 14, width: w - 2 * pad, height: 34))
            }
        }
    }

    // MARK: Classic — YouTube's own look, header band + lighter body in the tier colours

    private static func classic(_ e: SuperChat, _ showTotal: Bool) -> UIImage {
        let w: CGFloat = 860, pad: CGFloat = 28, r: CGFloat = 40
        let dark = lightTier(e.tier)
        let fg = dark ? UIColor(white: 0, alpha: 0.87) : .white
        let fgSoft = dark ? UIColor(white: 0, alpha: 0.6) : UIColor(white: 1, alpha: 0.7)
        let body = [e.message.isEmpty ? nil : e.message, showTotal ? e.total.map { "Total this stream: \($0)" } : nil]
            .compactMap { $0 }.joined(separator: "\n")
        let bodyFont = font(34)
        let bodyH = body.isEmpty ? 0 : textHeight(body, bodyFont, w - 2 * pad, 5)
        let head = pad * 2 + 2 * r
        let h = head + (bodyH > 0 ? bodyH + 2 * pad : 0)
        return card(w, h) { ctx, box in
            let shape = UIBezierPath(roundedRect: box, cornerRadius: 20)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 8), blur: 24, color: UIColor(white: 0, alpha: 0.4).cgColor)
            bright(e.tier).setFill(); shape.fill()
            ctx.restoreGState()
            ctx.saveGState(); shape.addClip()
            deep(e.tier).setFill(); UIRectFill(CGRect(x: box.minX, y: box.minY, width: box.width, height: head))
            ctx.restoreGState()
            avatar(e, center: CGPoint(x: box.minX + pad + r, y: box.minY + pad + r), r: r, ring: nil)
            let tx = box.minX + pad + 2 * r + 22
            draw(e.name, font(32), fgSoft, CGRect(x: tx, y: box.minY + pad + 2, width: box.maxX - pad - tx, height: 40))
            draw(e.amount, font(36, .bold), fg, CGRect(x: tx, y: box.minY + pad + 40, width: box.maxX - pad - tx, height: 46))
            if bodyH > 0 {
                draw(body, bodyFont, fg, CGRect(x: box.minX + pad, y: box.minY + head + pad, width: w - 2 * pad, height: bodyH), lines: 5)
            }
        }
    }

    // MARK: Minimal — one slim line, amount badge + name + message

    private static func minimal(_ e: SuperChat) -> UIImage {
        let h: CGFloat = 104, r: CGFloat = 30
        let amountFont = font(34, .bold), nameFont = font(32, .medium), msgFont = font(32)
        let badgeW = width(e.amount, amountFont) + 40
        let nameW = min(width(e.name, nameFont), 260)
        let msgW = min(width(e.message, msgFont), 640 - nameW)
        let lead: CGFloat = 22 + 2 * r + 18
        let tail: CGFloat = e.message.isEmpty ? 36 : 16 + msgW + 36
        let w = lead + badgeW + 20 + nameW + tail
        return card(w, h) { ctx, box in
            let shape = UIBezierPath(roundedRect: box, cornerRadius: h / 2)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 6), blur: 26, color: UIColor(white: 0, alpha: 0.5).cgColor)
            rgb(0x0A0A0C, 0.85).setFill(); shape.fill()
            ctx.restoreGState()
            let cy = box.midY
            var x = box.minX + 22
            avatar(e, center: CGPoint(x: x + r, y: cy), r: r, ring: bright(e.tier)); x += 2 * r + 18
            pill(e.amount, x: x, y: cy - 26, h: 52, fill: bright(e.tier), fg: lightTier(e.tier) ? UIColor(white: 0, alpha: 0.9) : .white, font: amountFont)
            x += badgeW + 20
            let lineY = cy - nameFont.lineHeight / 2
            draw(e.name, nameFont, .white, CGRect(x: x, y: lineY, width: nameW, height: nameFont.lineHeight + 2)); x += nameW + 16
            if !e.message.isEmpty {
                draw(e.message, msgFont, UIColor(white: 1, alpha: 0.8), CGRect(x: x, y: lineY, width: msgW, height: msgFont.lineHeight + 2))
            }
        }
    }

    // MARK: Neon — black card, glowing tier outline, the amount front and centre

    private static func neon(_ e: SuperChat, _ showTotal: Bool) -> UIImage {
        let w: CGFloat = 880, pad: CGFloat = 40
        let glow = bright(e.tier)
        let msgFont = font(34)
        let msgH = e.message.isEmpty ? 0 : textHeight(e.message, msgFont, w - 2 * pad, 3)
        let totalLine = showTotal ? e.total.map { "Total this stream  \($0)" } : nil
        let h = pad + 96 + 52 + (msgH > 0 ? 20 + msgH : 0) + (totalLine != nil ? 48 : 0) + pad
        return card(w, h) { ctx, box in
            let shape = UIBezierPath(roundedRect: box, cornerRadius: 28)
            rgb(0x05050A, 0.96).setFill(); shape.fill()
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 26, color: glow.cgColor)
            glow.setStroke(); shape.lineWidth = 5; shape.stroke(); shape.stroke()     // twice: a brighter, tighter glow
            ctx.restoreGState()
            let inner = w - 2 * pad
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 22, color: glow.cgColor)
            draw(e.amount, font(84, .bold), glow, CGRect(x: box.minX + pad, y: box.minY + pad - 6, width: inner, height: 104), align: .center)
            ctx.restoreGState()
            draw(e.name, font(34, .medium), .white, CGRect(x: box.minX + pad, y: box.minY + pad + 100, width: inner, height: 44), align: .center)
            var y = box.minY + pad + 96 + 52
            if msgH > 0 {
                y += 20
                draw(e.message, msgFont, UIColor(white: 1, alpha: 0.9), CGRect(x: box.minX + pad, y: y, width: inner, height: msgH), align: .center, lines: 3)
                y += msgH
            }
            if let totalLine {
                draw(totalLine, font(26), UIColor(white: 1, alpha: 0.6), CGRect(x: box.minX + pad, y: y + 12, width: inner, height: 34), align: .center)
            }
        }
    }

    // MARK: Drawing helpers

    private static func card(_ w: CGFloat, _ h: CGFloat, _ body: (CGContext, CGRect) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = false
        let size = CGSize(width: ceil(w + 2 * margin), height: ceil(h + 2 * margin))
        return UIGraphicsImageRenderer(size: size, format: format).image { rc in
            body(rc.cgContext, CGRect(x: margin, y: margin, width: w, height: h))
        }
    }

    private static func rgb(_ v: UInt32, _ a: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
    }

    private static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont { .systemFont(ofSize: size, weight: weight) }

    private static func width(_ s: String, _ f: UIFont) -> CGFloat { ceil((s as NSString).size(withAttributes: [.font: f]).width) }

    /// Height of `s` wrapped to `w`, capped at `lines` lines.
    private static func textHeight(_ s: String, _ f: UIFont, _ w: CGFloat, _ lines: Int) -> CGFloat {
        let full = (s as NSString).boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude),
                                                options: .usesLineFragmentOrigin, attributes: [.font: f], context: nil).height
        return ceil(min(full, f.lineHeight * CGFloat(lines)))
    }

    private static func draw(_ s: String, _ f: UIFont, _ color: UIColor, _ rect: CGRect, align: NSTextAlignment = .left,
                             lines: Int = 1, kern: CGFloat = 0) {
        let p = NSMutableParagraphStyle()
        p.alignment = align
        // One line truncates with "…"; several lines wrap and truncate the last visible one.
        p.lineBreakMode = lines > 1 ? .byWordWrapping : .byTruncatingTail
        let a: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: color, .paragraphStyle: p, .kern: kern]
        (s as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: a, context: nil)
    }

    private static func gradient(_ ctx: CGContext, _ colors: [UIColor], from: CGPoint, to: CGPoint) {
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil) else { return }
        ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private static func pill(_ s: String, x: CGFloat, y: CGFloat, h: CGFloat, fill: UIColor, fg: UIColor, font f: UIFont) {
        let w = width(s, f) + 40
        fill.setFill(); UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: h / 2).fill()
        draw(s, f, fg, CGRect(x: x + 20, y: y + (h - f.lineHeight) / 2, width: w - 40 + 2, height: f.lineHeight + 2))
    }

    /// Round avatar (or the first letter on the tier colour), with an optional ring.
    private static func avatar(_ e: SuperChat, center c: CGPoint, r: CGFloat, ring: UIColor?) {
        let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState(); UIBezierPath(ovalIn: rect).addClip()
        if let img = e.avatar {
            let s = 2 * r / min(img.size.width, img.size.height)
            let sz = CGSize(width: img.size.width * s, height: img.size.height * s)
            img.draw(in: CGRect(x: c.x - sz.width / 2, y: c.y - sz.height / 2, width: sz.width, height: sz.height))
        } else {
            gradient(ctx, [bright(e.tier), deep(e.tier)], from: rect.origin, to: CGPoint(x: rect.maxX, y: rect.maxY))
            let f = font(r, .bold)
            draw(String(e.name.prefix(1)).uppercased(), f, .white,
                 CGRect(x: rect.minX, y: c.y - f.lineHeight / 2, width: rect.width, height: f.lineHeight + 2), align: .center)
        }
        ctx.restoreGState()
        if let ring {
            ring.setStroke()
            let o = UIBezierPath(ovalIn: rect.insetBy(dx: -3, dy: -3)); o.lineWidth = 4; o.stroke()
        }
    }
}
