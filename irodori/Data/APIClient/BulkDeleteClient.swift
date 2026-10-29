//
//  BulkDeleteClient.swift
//  irodori
//
//  コーデ・クローゼットの服をまとめて削除する。
//  POST api/coordinate/delete-bulk {uid, coordinate_ids}  (クローゼットの服は残る)
//  POST api/items/delete-bulk      {uid, item_ids}        (同一アイテムの隠れ重複も消える)
//  サーバが古く一括の入口が無いとき (404) は、1件ずつの削除を同時に送る。
//

import Foundation

struct BulkDeleteResult: Decodable {
    let deleted: [String]
    let failed: [String]
}

protocol BulkDeleteClientProtocol {
    func deleteCoordinates(uid: String, ids: [String]) async -> BulkDeleteResult
    func deleteItems(uid: String, ids: [String]) async -> BulkDeleteResult
}

final class BulkDeleteClient: BulkDeleteClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func deleteCoordinates(uid: String, ids: [String]) async -> BulkDeleteResult {
        if let r = await post("api/coordinate/delete-bulk", body: ["uid": uid, "coordinate_ids": ids]) { return r }
        let single = DeleteCoordinateClient()
        return await eachInParallel(ids) { id in
            if case .success(let res)? = try? await single.delete(uid: uid, coordinateId: id) { return res.success }
            return false
        }
    }

    func deleteItems(uid: String, ids: [String]) async -> BulkDeleteResult {
        if let r = await post("api/items/delete-bulk", body: ["uid": uid, "item_ids": ids]) { return r }
        let single = DeleteClosetItemClient()
        return await eachInParallel(ids) { id in
            if case .success(let res)? = try? await single.delete(uid: uid, itemId: id) { return res.success }
            return false
        }
    }

    /// 一括の入口に送る。入口が無い (404) / 通信できないときは nil
    private func post(_ path: String, body: [String: Any]) async -> BulkDeleteResult? {
        guard let url = URL(string: "\(baseURL)/\(path)"),
              let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        request.timeoutInterval = 60
        guard let (resData, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode < 400 else { return nil }
        return try? JSONDecoder().decode(BulkDeleteResult.self, from: resData)
    }

    private func eachInParallel(_ ids: [String], _ op: @escaping @Sendable (String) async -> Bool) async -> BulkDeleteResult {
        await withTaskGroup(of: (String, Bool).self) { group in
            for id in ids { group.addTask { (id, await op(id)) } }
            var deleted: [String] = [], failed: [String] = []
            for await (id, ok) in group { ok ? deleted.append(id) : failed.append(id) }
            return BulkDeleteResult(deleted: deleted, failed: failed)
        }
    }
}
