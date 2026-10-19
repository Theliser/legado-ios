import Foundation

extension QueryTTF {
    func parseFont(data: Data) {
        let reader = BufferReader(data: data, offset: 0)
        fileHeader.sfntVersion = reader.readUInt32()
        fileHeader.numTables = Int(reader.readUInt16())
        fileHeader.searchRange = Int(reader.readUInt16())
        fileHeader.entrySelector = Int(reader.readUInt16())
        fileHeader.rangeShift = Int(reader.readUInt16())

        for _ in 0 ..< fileHeader.numTables {
            let tagData = reader.readByteArray(4)
            let tag = String(data: tagData, encoding: .ascii) ?? ""
            let checkSum = reader.readUInt32()
            let offset = Int(reader.readUInt32())
            let length = Int(reader.readUInt32())
            directories[tag] = Directory(tableTag: tag, checkSum: checkSum, offset: offset, length: length)
        }

        readHeadTable(data: data)
        readMaxpTable(data: data)
        readLocaTable(data: data)
        readCmapTable(data: data)
        readGlyfTable(data: data)

        let glyfCount = glyfArray.count
        for (unicodeKey, glyphId) in unicodeToGlyphId {
            guard glyphId < glyfCount, let glyfString = getGlyfById(glyphId) else { continue }
            unicodeToGlyph[unicodeKey] = glyfString
            glyphToUnicode[glyfString] = unicodeKey
        }
    }

    func readHeadTable(data: Data) {
        guard let table = directories["head"] else { return }
        let reader = BufferReader(data: data, offset: table.offset)
        head.majorVersion = Int(reader.readUInt16())
        head.minorVersion = Int(reader.readUInt16())
        head.fontRevision = reader.readUInt32()
        head.checkSumAdjustment = reader.readUInt32()
        head.magicNumber = reader.readUInt32()
        head.flags = Int(reader.readUInt16())
        head.unitsPerEm = Int(reader.readUInt16())
        head.created = reader.readUInt64()
        head.modified = reader.readUInt64()
        head.xMin = reader.readInt16()
        head.yMin = reader.readInt16()
        head.xMax = reader.readInt16()
        head.yMax = reader.readInt16()
        head.macStyle = Int(reader.readUInt16())
        head.lowestRecPPEM = Int(reader.readUInt16())
        head.fontDirectionHint = reader.readInt16()
        head.indexToLocFormat = reader.readInt16()
        head.glyphDataFormat = reader.readInt16()
    }

    func readMaxpTable(data: Data) {
        guard let table = directories["maxp"] else { return }
        let reader = BufferReader(data: data, offset: table.offset)
        maxp.version = reader.readUInt32()
        maxp.numGlyphs = Int(reader.readUInt16())
        maxp.maxPoints = Int(reader.readUInt16())
        maxp.maxContours = Int(reader.readUInt16())
        maxp.maxCompositePoints = Int(reader.readUInt16())
        maxp.maxCompositeContours = Int(reader.readUInt16())
    }

    func readLocaTable(data: Data) {
        guard let table = directories["loca"] else { return }
        let reader = BufferReader(data: data, offset: table.offset)
        if head.indexToLocFormat == 0 {
            let count = table.length / 2
            var arr = reader.readUInt16Array(count)
            for idx in 0 ..< arr.count {
                arr[idx] *= 2
            }
            loca = arr
        } else {
            let count = table.length / 4
            loca = reader.readInt32Array(count)
        }
    }

    func readCmapTable(data: Data) {
        guard let table = directories["cmap"] else { return }
        let reader = BufferReader(data: data, offset: table.offset)
        _ = reader.readUInt16() // version
        let numTables = Int(reader.readUInt16())
        var records: [CmapRecord] = []
        for _ in 0 ..< numTables {
            let platformID = Int(reader.readUInt16())
            let encodingID = Int(reader.readUInt16())
            let offset = Int(reader.readUInt32())
            records.append(CmapRecord(platformID: platformID, encodingID: encodingID, offset: offset))
        }

        var parsedOffsets: Set<Int> = []
        for record in records {
            let fmtOffset = record.offset
            guard !parsedOffsets.contains(fmtOffset) else { continue }
            parsedOffsets.insert(fmtOffset)
            parseCmapFormat(tableOffset: table.offset, fmtOffset: fmtOffset, reader: reader)
        }
    }

    private func parseCmapFormat(tableOffset: Int, fmtOffset: Int, reader: BufferReader) {
        reader.position(tableOffset + fmtOffset)
        let format = Int(reader.readUInt16())
        let length = Int(reader.readUInt16())
        _ = reader.readUInt16() // language

        switch format {
        case 0:
            readCmapFormat0(length: length, reader: reader)

        case 4:
            readCmapFormat4(length: length, reader: reader)

        case 6:
            readCmapFormat6(reader: reader)

        default:
            break
        }
    }

    private func readCmapFormat0(length: Int, reader: BufferReader) {
        let count = max(0, length - 6)
        let glyphIds = reader.readUInt8Array(count)
        for unicode in 0 ..< glyphIds.count where glyphIds[unicode] != 0 {
            unicodeToGlyphId[unicode] = glyphIds[unicode]
        }
    }

    private func readCmapFormat4(length: Int, reader: BufferReader) {
        let segCountX2 = Int(reader.readUInt16())
        let segCount = segCountX2 / 2
        _ = reader.readUInt16() // searchRange
        _ = reader.readUInt16() // entrySelector
        _ = reader.readUInt16() // rangeShift
        let endCode = reader.readUInt16Array(segCount)
        _ = reader.readUInt16() // reservedPad
        let startCode = reader.readUInt16Array(segCount)
        let idDelta = reader.readInt16Array(segCount)
        let idRangeOffsets = reader.readUInt16Array(segCount)
        let glyphIdArrayLength = max(0, (length - 16 - (segCount * 8)) / 2)
        let glyphIdArray = reader.readUInt16Array(glyphIdArrayLength)

        for segmentIndex in 0 ..< segCount {
            let start = startCode[segmentIndex]
            let end = endCode[segmentIndex]
            let delta = idDelta[segmentIndex]
            let rangeOffset = idRangeOffsets[segmentIndex]

            for unicode in start ... end {
                let glyphId: Int
                if rangeOffset == 0 {
                    glyphId = (unicode + delta) & 0xFFFF
                } else {
                    let gIndex = (rangeOffset / 2) + unicode - start + segmentIndex - segCount
                    if gIndex >= 0, gIndex < glyphIdArray.count {
                        glyphId = (glyphIdArray[gIndex] + delta) & 0xFFFF
                    } else {
                        glyphId = 0
                    }
                }
                if glyphId != 0 {
                    unicodeToGlyphId[unicode] = glyphId
                }
            }
        }
    }

    private func readCmapFormat6(reader: BufferReader) {
        let firstCode = Int(reader.readUInt16())
        let entryCount = Int(reader.readUInt16())
        let glyphIdArray = reader.readUInt16Array(entryCount)
        for (gIndex, gid) in glyphIdArray.enumerated() where gid != 0 {
            let unicodeVal = firstCode + gIndex
            unicodeToGlyphId[unicodeVal] = gid
        }
    }

    func readGlyfTable(data: Data) {
        guard let table = directories["glyf"] else { return }
        let glyfCount = maxp.numGlyphs
        guard glyfCount > 0, loca.count > glyfCount else { return }
        glyfArray = [GlyfLayout?](repeating: nil, count: glyfCount)

        let reader = BufferReader(data: data, offset: 0)
        for index in 0 ..< glyfCount {
            if loca[index] == loca[index + 1] {
                continue
            }
            let offset = table.offset + loca[index]
            guard offset < data.count else { continue }
            reader.position(offset)

            let glyph = GlyfLayout()
            glyph.numberOfContours = reader.readInt16()
            if maxp.maxContours > 0, glyph.numberOfContours > Int16(maxp.maxContours) {
                continue
            }
            glyph.xMin = reader.readInt16()
            glyph.yMin = reader.readInt16()
            glyph.xMax = reader.readInt16()
            glyph.yMax = reader.readInt16()

            if glyph.numberOfContours == 0 {
                continue
            }
            if glyph.numberOfContours > 0 {
                glyph.glyphSimple = readSimpleGlyph(contours: Int(glyph.numberOfContours), reader: reader)
            } else {
                glyph.glyphComponent = readComponentGlyph(reader: reader)
            }
            glyfArray[index] = glyph
        }
    }

    private func readSimpleGlyph(contours: Int, reader: BufferReader) -> GlyphSimple {
        var simple = GlyphSimple()
        simple.endPtsOfContours = reader.readUInt16Array(contours)
        simple.instructionLength = Int(reader.readUInt16())
        simple.instructions = reader.readUInt8Array(simple.instructionLength)
        let flagLength = (simple.endPtsOfContours.last ?? 0) + 1

        var flags = [Int](repeating: 0, count: flagLength)
        var flagIdx = 0
        while flagIdx < flagLength && !reader.isEOF {
            let flag = Int(reader.readUInt8())
            flags[flagIdx] = flag
            flagIdx += 1
            if (flag & 0x08) != 0 && flagIdx < flagLength {
                let repeatCount = Int(reader.readUInt8())
                for _ in 0 ..< repeatCount where flagIdx < flagLength {
                    flags[flagIdx] = flag
                    flagIdx += 1
                }
            }
        }
        simple.flags = flags
        simple.xCoordinates = readCoordinates(flags: flags, reader: reader, isX: true)
        simple.yCoordinates = readCoordinates(flags: flags, reader: reader, isX: false)
        return simple
    }

    private func readCoordinates(flags: [Int], reader: BufferReader, isX: Bool) -> [Int] {
        var coords = [Int](repeating: 0, count: flags.count)
        for idx in 0 ..< flags.count {
            let flag = flags[idx]
            let mask = isX ? 0x12 : 0x24
            let shortPos = isX ? 0x12 : 0x24
            let shortNeg = isX ? 0x02 : 0x04
            let sameVal = isX ? 0x10 : 0x20

            if (flag & mask) == shortPos {
                coords[idx] = Int(reader.readUInt8())
            } else if (flag & mask) == shortNeg {
                coords[idx] = -1 * Int(reader.readUInt8())
            } else if (flag & sameVal) != 0 {
                coords[idx] = 0
            } else {
                coords[idx] = Int(reader.readInt16())
            }
        }
        return coords
    }

    private func readComponentGlyph(reader: BufferReader) -> [GlyphComponent] {
        var components: [GlyphComponent] = []
        while !reader.isEOF {
            var comp = GlyphComponent()
            comp.flags = Int(reader.readUInt16())
            comp.glyphIndex = Int(reader.readUInt16())

            switch comp.flags & 0b11 {
            case 0b00:
                comp.argument1 = Int(reader.readUInt8())
                comp.argument2 = Int(reader.readUInt8())

            case 0b10:
                comp.argument1 = Int(reader.readInt8())
                comp.argument2 = Int(reader.readInt8())

            case 0b01:
                comp.argument1 = Int(reader.readUInt16())
                comp.argument2 = Int(reader.readUInt16())

            case 0b11:
                comp.argument1 = Int(reader.readInt16())
                comp.argument2 = Int(reader.readInt16())

            default:
                break
            }

            applyComponentScales(&comp, reader: reader)
            components.append(comp)
            if (comp.flags & 0x20) == 0 {
                break
            }
        }
        return components
    }

    private func applyComponentScales(_ comp: inout GlyphComponent, reader: BufferReader) {
        switch comp.flags & 0b1100_1000 {
        case 0b0000_1000:
            let scaleVal = Float(reader.readUInt16()) / 16384.0
            comp.xScale = scaleVal
            comp.yScale = scaleVal

        case 0b0100_0000:
            comp.xScale = Float(reader.readUInt16()) / 16384.0
            comp.yScale = Float(reader.readUInt16()) / 16384.0

        case 0b1000_0000:
            comp.xScale = Float(reader.readUInt16()) / 16384.0
            comp.scale01 = Float(reader.readUInt16()) / 16384.0
            comp.scale10 = Float(reader.readUInt16()) / 16384.0
            comp.yScale = Float(reader.readUInt16()) / 16384.0

        default:
            break
        }
    }
}
