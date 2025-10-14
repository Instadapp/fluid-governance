import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { configVariable } from "hardhat/config";

export default buildModule("PayloadModule", (m) => {
  const payload = m.contract(`PayloadIGP${process.env.IGP_ID}`);

  return { payload };
});
