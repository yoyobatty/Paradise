use byondapi::value::ByondValue;
use png::{Decoder, Encoder, OutputInfo, Reader};
use std::fs::File;
use std::io::BufReader;

#[byondapi::bind]
fn dmi_strip_metadata(path: ByondValue) -> eyre::Result<ByondValue> {
    strip_metadata(&path.get_string()?)?;
    Ok(ByondValue::null())
}

fn strip_metadata(path: &str) -> eyre::Result<()> {
    let (reader, frame_info, image) = read_png(path)?;
    write_png(path, &reader, &frame_info, &image, true)
}

fn read_png(path: &str) -> eyre::Result<(Reader<BufReader<File>>, OutputInfo, Vec<u8>)> {
    let mut reader = Decoder::new(BufReader::new(File::open(path)?)).read_info()?;
    let buffer_size = reader
        .output_buffer_size()
        .ok_or_else(|| eyre::eyre!("{path} is too big to decode"))?;
    let mut buf = vec![0; buffer_size];
    let frame_info = reader.next_frame(&mut buf)?;

    Ok((reader, frame_info, buf))
}

fn write_png(
    path: &str,
    reader: &Reader<BufReader<File>>,
    info: &OutputInfo,
    image: &[u8],
    strip: bool,
) -> eyre::Result<()> {
    let mut encoder = Encoder::new(File::create(path)?, info.width, info.height);
    encoder.set_color(info.color_type);
    encoder.set_depth(info.bit_depth);

    let reader_info = reader.info();
    if let Some(palette) = reader_info.palette.clone() {
        encoder.set_palette(palette);
    }

    if let Some(trns_chunk) = reader_info.trns.clone() {
        encoder.set_trns(trns_chunk);
    }

    let mut writer = encoder.write_header()?;
    // Handles zTxt chunk copying from the original image if we /don't/ want to strip it
    if !strip {
        for chunk in &reader_info.compressed_latin1_text {
            writer.write_text_chunk(chunk)?;
        }
    }
    Ok(writer.write_image_data(image)?)
}
