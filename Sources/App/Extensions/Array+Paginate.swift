import Fluent
import Vapor

extension Array where Element: Codable {
    func paginate(for req: Request) throws -> Page<Element> {
        guard let page = try? req.query.decode(PageRequest.self) else {
            req.logger.error("Failed to decode page metadata")
            throw Abort(.badRequest)
        }

        let total = self.count
        let per = page.per
        let requestPage: Int = Swift.min(Int(ceil(Float(total) / Float(per))), page.page) 
        let left = Swift.max(per * (requestPage - 1), 0) 
        let right = Swift.min(left + per, total)

        let copy = self
        let slice = copy[left..<right]

        return Page(
            items: Array(slice), 
            metadata: PageMetadata(
                    page: requestPage, 
                    per: per, 
                    total: total
                )
            )
    }

    func paginate(for page: PageRequest) -> Page<Element> {

        let total = self.count
        let per = page.per
        let requestPage: Int = Swift.min(Int(ceil(Float(total) / Float(per))), page.page) 
        let left = Swift.max(per * (requestPage - 1), 0) 
        let right = Swift.min(left + per, total)

        let slice = self[left..<right]

        return Page(
            items: Array(slice), 
            metadata: PageMetadata(
                    page: requestPage, 
                    per: per, 
                    total: total
                )
            )
    }
}