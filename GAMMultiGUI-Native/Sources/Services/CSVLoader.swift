import Foundation

struct CSVLoader {
    func loadRows(from path: String) throws -> [CSVRow] {
        let fileURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AppError.csvFileNotFound(fileURL.path)
        }

        let data = try Data(contentsOf: fileURL)
        guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf8) else {
            throw AppError.invalidCSV("Could not decode file as UTF-8.")
        }

        if text.hasPrefix("\u{feff}") {
            text.removeFirst()
        }

        let records = try parseCSV(text)
        guard let header = records.first, !header.isEmpty else {
            throw AppError.invalidCSV("Missing header row.")
        }

        let normalizedHeader = header.map(normalizeHeader)
        let accountIndex = try index(for: "account", in: normalizedHeader)
        let messageIndex = try index(for: "rfc822messageid", in: normalizedHeader)

        var rows: [CSVRow] = []
        for (offset, record) in records.dropFirst().enumerated() {
            let padded = pad(record, to: header.count)
            var fields: [String: String] = [:]
            for (columnIndex, name) in header.enumerated() {
                fields[name] = cleanField(columnIndex < padded.count ? padded[columnIndex] : "")
            }

            let account = cleanUser(accountIndex < padded.count ? padded[accountIndex] : "")
            let messageID = cleanMessageID(messageIndex < padded.count ? padded[messageIndex] : "")

            rows.append(
                CSVRow(
                    rowNumber: offset + 1,
                    account: account,
                    rfc822MessageID: messageID,
                    rawFields: fields
                )
            )
        }

        return rows
    }

    private func index(for key: String, in headers: [String]) throws -> Int {
        guard let index = headers.firstIndex(of: key) else {
            throw AppError.invalidCSV("Expected column \(key).")
        }
        return index
    }

    private func normalizeHeader(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .lowercased()
    }

    private func cleanField(_ value: String) -> String {
        value.replacingOccurrences(of: "\r", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanUser(_ value: String) -> String {
        cleanField(value).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private func cleanMessageID(_ value: String) -> String {
        let cleaned = cleanField(value)
        if cleaned.hasPrefix("<"), cleaned.hasSuffix(">"), cleaned.count >= 2 {
            return String(cleaned.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    private func pad(_ record: [String], to count: Int) -> [String] {
        if record.count >= count {
            return record
        }
        return record + Array(repeating: "", count: count - record.count)
    }

    private func parseCSV(_ text: String) throws -> [[String]] {
        var records: [[String]] = []
        var currentRecord: [String] = []
        var currentField = ""
        var insideQuotes = false

        var iterator = text.makeIterator()
        while let character = iterator.next() {
            switch character {
            case "\"":
                if insideQuotes {
                    if let next = iterator.next() {
                        if next == "\"" {
                            currentField.append("\"")
                        } else {
                            insideQuotes = false
                            processNonQuote(next, currentField: &currentField, currentRecord: &currentRecord, records: &records, insideQuotes: &insideQuotes)
                        }
                    } else {
                        insideQuotes = false
                    }
                } else {
                    insideQuotes = true
                }
            default:
                processNonQuote(character, currentField: &currentField, currentRecord: &currentRecord, records: &records, insideQuotes: &insideQuotes)
            }
        }

        if insideQuotes {
            throw AppError.invalidCSV("Unterminated quoted field.")
        }

        if !currentField.isEmpty || !currentRecord.isEmpty {
            currentRecord.append(currentField)
            records.append(currentRecord)
        }

        return records.filter { record in
            !record.isEmpty && !(record.count == 1 && record[0].isEmpty)
        }
    }

    private func processNonQuote(
        _ character: Character,
        currentField: inout String,
        currentRecord: inout [String],
        records: inout [[String]],
        insideQuotes: inout Bool
    ) {
        if insideQuotes {
            currentField.append(character)
            return
        }

        switch character {
        case ",":
            currentRecord.append(currentField)
            currentField = ""
        case "\n":
            currentRecord.append(currentField)
            records.append(currentRecord)
            currentRecord = []
            currentField = ""
        case "\r":
            break
        default:
            currentField.append(character)
        }
    }
}
