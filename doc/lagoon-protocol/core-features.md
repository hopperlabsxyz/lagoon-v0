# Core Features

Lagoon Protocol is packed with powerful features designed to offer unparalleled flexibility, security, and functionality in the decentralized finance (DeFi) space. Below, we outline the core features that make Lagoon Protocol a leading solution for digital asset management and DeFi strategies.

## **Customizable Hopper Vaults**

At the heart of Lagoon Protocol are the Lagoon Vaults—smart contract-based vaults that securely hold and manage assets. Hopper Vaults are designed with rapid adaptability and flexibility in mind, allowing asset manager to configure them according to their specific needs. Key attributes include:

### Scalable Asset Management

**Scalable Asset Management** is designed to facilitate the scalable onboarding and management of fund depositors for asset managers. By leveraging smart contract technology and a robust permissions framework, Lagoon Protocol enables asset managers to efficiently handle a growing number of deposits while maintaining control and oversight. Key elements include:

* **Seamless Integration with DeFi Protocols:** By facilitating connections to a range of whitelisted DeFi protocols, Lagoon Protocol allows asset managers to optimize the performance of deposits through yield generation, liquidity provision, and other DeFi strategies without compromising security.
* **Scalable Governance Structures:** Asset managers can establish governance frameworks that scale with their growing community of fund depositors. This ensures that all fund depositors have a voice in the decision-making process, fostering a collaborative environment that enhances trust and accountability.

Overall, the Asset Management feature of Lagoon Protocol empowers asset managers to efficiently scale their operations, attract a wider range of fund depositors, and optimize asset performance through innovative DeFi strategies.

### Whitelisting DeFi Protocols for Secure and Controlled Operations

**Whitelisting DeFi Protocols** refers to the ability to define and restrict which DeFi protocols a Lagoon Vault can interact with. This feature is crucial for maintaining separation of power and ensuring that only pre-approved, trusted protocols can be used for asset management and transactions. By whitelisting specific DeFi protocols, the vault creator can:

* **Mitigate Risk:** Limit exposure to only vetted and reliable protocols, reducing the risk of interacting with untested or insecure DeFi platforms.
* **Ensure Compliance:** Align with requirements or internal guidelines by allowing only certain protocols that meet specific standards.
* **Enforce Governance:** Empower governance participants to vote on which protocols should be added or removed from the whitelist, maintaining control over the vault’s operations.
* Bringing Transparency: Ensure transparency of DeFi strategies, making all actions within the vault predictable and accountable to all fund depositors, thereby fostering trust and confidence in secure asset management.

### Permissions for Authorizing Only a List of Fund Depositors

**Permissions for Fund Depositors** involves the ability to control who can deposit assets into the Lagoon Vault. This is achieved through a permissions system that authorizes only a specific list of fund depositors. This feature allows for:

* **Controlled Access:** Restrict asset deposits to a pre-approved list of users, ensuring that only trusted entities can contribute to the vault.
* **Security Enhancement:** Prevent unauthorized users from depositing assets, reducing the risk of malicious activities or unapproved asset inflows.
* **Tailored User Experience:** Customize the vault's operations to align with the specific needs and goals of the fund, such as focusing on high-net-worth individuals, institutional investors, or a select community.
* **Governance Oversight:** Provide the vault’s governance structure with the ability to manage and update the list of authorized depositors, maintaining control over the vault’s contributors.

The permissions for authorized fund depositors can be revoked at any time by the Vault Creator role.

## **Roles-Based Access Control**

Lagoon Protocol utilizes a granular roles-based access control system, powered by Zodiac Roles Modifier, to ensure that only authorized individuals can perform specific actions within the Hopper Vaults. The main roles include:

* **Vault Creator**: The individual or entity responsible for creating and configuring the Hopper Vault. This role has the authority to update Gnosis Safe and vault settings and assign other roles.
* **Asset Manager**: Tasked with executing transactions and implementing DeFi strategies within the vault. The Asset Manager is also crucial for settle the Net Asset Value (NAV).
* **NAV Committee**: Responsible for updating the Net Asset Value (NAV) of the Lagoon Vault, ensuring accurate valuation of the vault’s assets.
* **Fund Depositors**: Users who deposit assets into the vault and receive shares representing their ownership stake.

## **Advanced Fee Management**

Lagoon Protocol provides extensive support for fee management, enabling Vault Creators to define, update, or remove various fee types:

* **Entry/Exit Fees**: Fees applied when users deposit into or withdraw from the vault.
* **Performance Fees**: Deducted based on the profitability of the vault’s investments, based on a **high water mark** system.
* **Management Fees**: Regular fees for managing the vault, typically a percentage of assets under management.

These fees are automatically calculated and managed within the Lagoon Vaults, ensuring transparency and efficiency.

## **Net Asset Value (NAV) Management**

Accurate NAV calculations are crucial for the financial integrity of Lagoon Vaults. Lagoon Protocol offers a sophisticated system for initiating, updating, and settling NAVs.

It incorporates a structured three-step process for managing the Net Asset Value (NAV) of its vaults, ensuring clarity and accountability throughout. This process involves the roles of both the NAV Committee and the Asset Manager, facilitating effective asset management and transparency for all Fund Depositors. The steps include:

1. **NAV Update by the NAV Committee Role:** The NAV Committee is responsible for periodically updating the NAV based on the performance and valuation of the underlying assets. This update ensures that the NAV accurately reflects the current market conditions and asset values, providing fund depositors with an up-to-date financial picture.
2. **NAV Settlement by the Asset Manager Role:** Once the NAV has been updated, the Asset Manager takes action to settle the NAV. This involves executing the necessary transactions to align the vault’s holdings with the updated NAV, ensuring that underlaying assets are appropriately provisioned to provide all withdraw requests.
3. **Fee Calculation and Distribution:** After the NAV is settled, the protocol calculates any applicable fees based on the vault's performance and predefined fee structures. These fees are then distributed to the relevant parties, such as the Asset Manager and any actors entitled to fee sharing, ensuring a fair compensation mechanism is in place for services rendered.
4. **Acceptance of Deposits and Distribution of Underlying Assets for Withdrawal Requests:** After the NAV has been settled, the vault is prepared to accept new deposits and process withdrawal requests. The underlying assets are then distributed according to the updated NAV, ensuring that all users can withdraw their assets accurately and in a timely manner.

This four-step NAV management process enhances the operational integrity of Lagoon Protocol, enabling effective oversight of asset values and ensuring that users’ investments are managed transparently and securely.

## **Interoperability and Cross-Chain Liquidity**

Lagoon Protocol is designed to operate seamlessly across multiple blockchain networks, including Ethereum and Layer 2 compatible with Gnosis Safe. This cross-chain capability allows Lagoon Vaults to manage assets and execute strategies across different ecosystems. Key benefits include:

* **Cross-Chain DeFi Strategies**: Execute complex strategies that involve assets and protocols across multiple blockchains.
* **Liquidity Management**: Optimize liquidity across chains while maintaining secure custody of assets.
* **Seamless Integration**: Effortlessly connect and interact with various DeFi protocols, regardless of their underlying blockchain.
* **Flexible Deposit and Withdrawal Options:** Fund depositors can deposit and withdraw assets on different layers for the same Lagoon Vault, allowing for greater flexibility in managing liquidity and optimizing asset performance.

Overall, the Interoperability and Cross-Chain Liquidity feature of Lagoon Protocol empowers asset managers and fund depositors to take full advantage of the diverse opportunities present in the DeFi landscape, ensuring efficient asset management and optimized liquidity across various blockchain networks.

## **Secure and Transparent Infrastructure**

Security is a top priority for Lagoon Protocol. By integrating with Gnosis Safe, Lagoon Protocol ensures that all asset management activities are conducted in a secure, multi-signature environment. This setup reduces the risk of unauthorized access and provides full transparency over all transactions.

* **Multi-Signature Wallets**: Hopper Vaults are protected by Gnosis Safe’s multi-signature wallets, requiring multiple approvals for transactions.
* **ERC-7450 Standard:** The ERC-7450 standard enhances the functionality and interoperability of the Lagoon Vaults, allowing for sophisticated asset management DeFi strategies due to asynchronies NAV update. This standard also facilitates smoother integrations with other DeFi protocols, making it easier to manage assets across different platforms.
* **Audit and Monitoring Tools**: Lagoon Protocol includes advanced tools for auditing smart contracts, optimizing gas usage, and monitoring vault activities.

## **Scalable and Extensible Architecture**

Lagoon Protocol’s modular architecture allows it to be easily extended and customized. Whether you’re looking to integrate new DeFi protocols, implement custom governance models, or build entirely new financial products, Lagoon Protocol provides a flexible foundation that can grow with your needs.
