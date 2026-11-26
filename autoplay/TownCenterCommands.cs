using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Xml;

public static class GaiaTownCenterCommands
{
    public static void Install(string archivePath, string destination, bool portuguese)
    {
        var entries = new Dictionary<string, byte[]>();
        using (var archive = new BinaryReader(File.OpenRead(archivePath)))
        {
            Expect(archive, "ESPN");
            if (archive.ReadInt32() != 6) throw new InvalidDataException("Versao BAR desconhecida.");
            archive.BaseStream.Position = 288;
            archive.BaseStream.Position = archive.ReadInt64();
            ReadString(archive);
            int count = archive.ReadInt32();
            for (int i = 0; i < count; i++)
            {
                long offset = archive.ReadInt64();
                archive.BaseStream.Position += 8;
                int length = archive.ReadInt32();
                string path = ReadString(archive);
                archive.BaseStream.Position += 4;
                if (path != @"gameplay\proto.xml.XMB" && path != @"gameplay\proto_unit_commands.xml.XMB")
                    continue;
                long next = archive.BaseStream.Position;
                archive.BaseStream.Position = offset;
                entries.Add(path, archive.ReadBytes(length));
                archive.BaseStream.Position = next;
            }
        }

        var commands = ReadXml(entries[@"gameplay\proto_unit_commands.xml.XMB"]);
        var farm = commands.SelectSingleNode("/protounitcommands/protounitcommand[name='ResourceUnitConstructFarm']")
            ?? throw new InvalidDataException("Comando de fazenda ausente.");
        var toggle = farm.CloneNode(true);
        toggle["name"].InnerText = "GaiaAutoplayToggle";
        toggle["command"].InnerText = "uiAutoScoutSelectedUnit(%d, true)";
        toggle["rollovertextid"].InnerText = "STR_GAIA_AUTOPLAY_TOGGLE";
        toggle.RemoveChild(toggle["trainableunitreq"]);
        farm.ParentNode.AppendChild(toggle);

        var units = ReadXml(entries[@"gameplay\proto.xml.XMB"]);
        foreach (string center in new[] { "TownCenter", "VillageCenter", "CitadelCenter" })
        {
            var slot = units.SelectSingleNode("/proto/unit[@name='" + center + "']/command[@row='2' and @column='5' and text()='ResourceUnitConstructFarm']")
                ?? throw new InvalidDataException("Comando de fazenda ausente em " + center);
            slot.InnerText = "GaiaAutoplayToggle";
        }
        var gameplay = Directory.CreateDirectory(Path.Combine(destination, "gameplay")).FullName;
        var strings = Directory.CreateDirectory(Path.Combine(destination, "strings",
            portuguese ? "PortugueseBrazil" : "English")).FullName;
        string language = portuguese ? "PortugueseBrazil" : "English";
        string title = portuguese ? "Gaia Autoplay - Ligar ou desligar" : "Gaia Autoplay - Toggle";
        File.WriteAllText(Path.Combine(strings, "stringmods.txt"),
            "Language = \"" + language + "\"\r\nIsRtl = \"False\"\r\n" +
            "ID = \"STR_GAIA_AUTOPLAY_TOGGLE\" ; Str = \"" + title + "\"\r\n");
        commands.Save(Path.Combine(gameplay, "proto_unit_commands.xml"));
        units.Save(Path.Combine(gameplay, "proto.xml"));
    }

    private static XmlDocument ReadXml(byte[] bytes)
    {
        using (var input = new BinaryReader(new MemoryStream(Decompress(bytes))))
        {
            Expect(input, "X1");
            input.ReadInt32();
            Expect(input, "XR");
            if (input.ReadInt32() != 4 || input.ReadInt32() != 8)
                throw new InvalidDataException("Versao XMB desconhecida.");
            var elements = ReadNames(input);
            var attributes = ReadNames(input);
            var document = new XmlDocument();
            document.AppendChild(ReadElement(input, document, elements, attributes));
            return document;
        }
    }

    private static XmlElement ReadElement(BinaryReader input, XmlDocument document, string[] elements, string[] attributes)
    {
        Expect(input, "XN");
        input.ReadInt32();
        string value = ReadString(input);
        var element = document.CreateElement(elements[input.ReadInt32()]);
        if (value.Length > 0) element.InnerText = value;
        input.ReadInt32();
        int count = input.ReadInt32();
        for (int i = 0; i < count; i++)
            element.SetAttribute(attributes[input.ReadInt32()], ReadString(input));
        count = input.ReadInt32();
        for (int i = 0; i < count; i++)
            element.AppendChild(ReadElement(input, document, elements, attributes));
        return element;
    }

    private static string[] ReadNames(BinaryReader input)
    {
        var names = new string[input.ReadInt32()];
        for (int i = 0; i < names.Length; i++) names[i] = ReadString(input);
        return names;
    }

    private static string ReadString(BinaryReader input)
    {
        return Encoding.Unicode.GetString(input.ReadBytes(checked(input.ReadInt32() * 2)));
    }

    private static void Expect(BinaryReader input, string expected)
    {
        if (Encoding.ASCII.GetString(input.ReadBytes(expected.Length)) != expected)
            throw new InvalidDataException("Cabecalho esperado: " + expected);
    }

    // Retold wraps an LZ4 block with compressed and uncompressed sizes.
    private static byte[] Decompress(byte[] data)
    {
        using (var source = new BinaryReader(new MemoryStream(data)))
        {
            Expect(source, "alz4");
            var output = new byte[source.ReadInt32()];
            int compressedSize = source.ReadInt32();
            source.ReadInt32();
            if (compressedSize != data.Length - 16)
                throw new InvalidDataException("Tamanho ALZ4 divergente.");
            int position = 0;
            while (source.BaseStream.Position < source.BaseStream.Length)
            {
                int token = source.ReadByte();
                int length = ReadLength(source, token >> 4);
                if (source.Read(output, position, length) != length)
                    throw new EndOfStreamException();
                position += length;
                if (source.BaseStream.Position == source.BaseStream.Length) break;
                int offset = source.ReadUInt16();
                if (offset == 0 || offset > position) throw new InvalidDataException("Offset LZ4 invalido.");
                length = ReadLength(source, token & 15) + 4;
                for (int i = 0; i < length; i++, position++) output[position] = output[position - offset];
            }
            if (position != output.Length) throw new InvalidDataException("Tamanho XMB divergente.");
            return output;
        }
    }

    private static int ReadLength(BinaryReader source, int length)
    {
        if (length != 15) return length;
        int extra;
        do
        {
            extra = source.ReadByte();
            length += extra;
        } while (extra == 255);
        return length;
    }
}
