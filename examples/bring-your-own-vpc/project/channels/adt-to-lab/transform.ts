// Only admissions go to the lab, addressed to it in MSH-5. Every other message is filtered out.
import type { Transform } from "@cosyte/pathways";

export default ((msg) => {
  if (!msg.is("ADT^A01")) return null;
  msg.setField("MSH.5", "LAB");
  return msg;
}) satisfies Transform;
