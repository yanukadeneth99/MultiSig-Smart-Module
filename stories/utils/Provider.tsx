import { initialize, Network, Provider } from "@decentology/hyperverse/react";
import { Localhost, Ethereum } from "@decentology/hyperverse-evm/react";
import React, { FC } from "react";
import * as SmartModule from "../../source/react";
import "@decentology/hyperverse-evm/styles.css";
import * as dotenv from "dotenv";

export const HyperverseProvider: FC<any> = ({ children }) => {
  const hyperverse = initialize({
    blockchain: Ethereum,
    network: {
      type: Network.Testnet,
      chainId: 5,
      name: "goerli",
      networkUrl: `https://eth-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
    },
    modules: [
      {
        bundle: SmartModule,
        tenantId: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      },
    ],
  });
  return <Provider initialState={hyperverse}>{children}</Provider>;
};
