"""Signs an aligned APK with APK Signature Scheme v2 (RSA-PKCS1v1.5 / SHA-256).

Usage: python3 sign_apk.py in.apk out.apk keystore.p12 storepass

Implements https://source.android.com/docs/security/features/apksigning/v2 :
the signing block is inserted between the ZIP entries and the central directory,
and covers both, plus the end-of-central-directory record.
"""
import hashlib
import struct
import sys

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.serialization import pkcs12

V2_BLOCK_ID = 0x7109871A
SIG_RSA_PKCS1_SHA256 = 0x0103
MAGIC = b"APK Sig Block 42"
CHUNK = 1024 * 1024


def lp(b: bytes) -> bytes:
    return struct.pack("<I", len(b)) + b


def find_eocd(data: bytes) -> int:
    # EOCD is at least 22 bytes, comment up to 65535
    for i in range(len(data) - 22, max(-1, len(data) - 22 - 65536), -1):
        if data[i:i + 4] == b"PK\x05\x06":
            comment_len = struct.unpack("<H", data[i + 20:i + 22])[0]
            if i + 22 + comment_len == len(data):
                return i
    raise ValueError("EOCD not found")


def chunk_digest(sections) -> bytes:
    digests = []
    for sec in sections:
        for off in range(0, len(sec), CHUNK):
            chunk = sec[off:off + CHUNK]
            digests.append(hashlib.sha256(b"\xa5" + struct.pack("<I", len(chunk)) + chunk).digest())
    return hashlib.sha256(b"\x5a" + struct.pack("<I", len(digests)) + b"".join(digests)).digest()


def split(data: bytes):
    eocd = find_eocd(data)
    cd_size, cd_off = struct.unpack("<II", data[eocd + 12:eocd + 20])
    if cd_off + cd_size != eocd:
        raise ValueError("central directory not directly before EOCD")
    if data[cd_off - 16:cd_off] == MAGIC:
        raise ValueError("APK already has a signing block")
    return data[:cd_off], data[cd_off:eocd], data[eocd:], cd_off, eocd


def sign(apk_in: str, apk_out: str, ks_path: str, password: str) -> None:
    data = open(apk_in, "rb").read()
    entries, cdir, eocd_bytes, cd_off, _ = split(data)

    key, cert, _extra = pkcs12.load_key_and_certificates(open(ks_path, "rb").read(), password.encode())
    cert_der = cert.public_bytes(serialization.Encoding.DER)
    pub_der = key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)

    digest = chunk_digest([entries, cdir, eocd_bytes])
    digests = lp(lp(struct.pack("<I", SIG_RSA_PKCS1_SHA256) + lp(digest)))
    certs = lp(lp(cert_der))
    attrs = lp(b"")
    signed_data = digests + certs + attrs

    signature = key.sign(signed_data, padding.PKCS1v15(), hashes.SHA256())
    sigs = lp(lp(struct.pack("<I", SIG_RSA_PKCS1_SHA256) + lp(signature)))
    signer = lp(signed_data) + sigs + lp(pub_der)
    v2_value = lp(lp(signer))

    pair = struct.pack("<Q", 4 + len(v2_value)) + struct.pack("<I", V2_BLOCK_ID) + v2_value
    block_size = len(pair) + 8 + 16
    block = struct.pack("<Q", block_size) + pair + struct.pack("<Q", block_size) + MAGIC

    new_eocd = bytearray(eocd_bytes)
    struct.pack_into("<I", new_eocd, 16, cd_off + len(block))
    open(apk_out, "wb").write(entries + block + cdir + bytes(new_eocd))


def verify(apk: str) -> str:
    """Independent re-check: parse the block back out, recompute digest, verify signature."""
    data = open(apk, "rb").read()
    eocd = find_eocd(data)
    cd_size, cd_off = struct.unpack("<II", data[eocd + 12:eocd + 20])
    assert data[cd_off - 16:cd_off] == MAGIC, "no signing block"
    size_end = struct.unpack("<Q", data[cd_off - 24:cd_off - 16])[0]
    start = cd_off - size_end - 8
    size_start = struct.unpack("<Q", data[start:start + 8])[0]
    assert size_start == size_end, "block sizes differ"
    pairs = data[start + 8:cd_off - 24]
    p = 0
    v2 = None
    while p < len(pairs):
        ln = struct.unpack("<Q", pairs[p:p + 8])[0]
        pid = struct.unpack("<I", pairs[p + 8:p + 12])[0]
        if pid == V2_BLOCK_ID:
            v2 = pairs[p + 12:p + 8 + ln]
        p += 8 + ln
    assert v2 is not None, "no v2 block"

    def rd(buf, o):
        n = struct.unpack("<I", buf[o:o + 4])[0]
        return buf[o + 4:o + 4 + n], o + 4 + n

    signers, _ = rd(v2, 0)
    signer, _ = rd(signers, 0)
    signed_data, o = rd(signer, 0)
    sigs, o = rd(signer, o)
    pub, o = rd(signer, o)
    sig_entry, _ = rd(sigs, 0)
    alg = struct.unpack("<I", sig_entry[:4])[0]
    sig, _ = rd(sig_entry, 4)
    serialization.load_der_public_key(pub).verify(sig, signed_data, padding.PKCS1v15(), hashes.SHA256())
    digests, _ = rd(signed_data, 0)
    d_entry, _ = rd(digests, 0)
    stored, _ = rd(d_entry, 4)
    # digest over the APK with the signing block removed and the EOCD offset restored
    orig_eocd = bytearray(data[eocd:])
    struct.pack_into("<I", orig_eocd, 16, start)
    actual = chunk_digest([data[:start], data[cd_off:eocd], bytes(orig_eocd)])
    assert actual == stored, "content digest mismatch"
    return "v2 signature OK (alg 0x%04x, %d bytes signed)" % (alg, len(data))


if __name__ == "__main__":
    if sys.argv[1] == "verify":
        print(verify(sys.argv[2]))
    else:
        sign(*sys.argv[1:5])
        print(verify(sys.argv[2]))
