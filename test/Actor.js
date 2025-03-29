const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Actor", function () {
    let Actor, actor, owner, account1, account2, authorizedContract;
    let AccessManager, accessManager;
    const hash = "QmX...TESTHASH";
    const newHash = "QmX...NEWTESTHASH";

    beforeEach(async function () {
        [owner, account1, account2, authorizedContract] = await ethers.getSigners();

        AccessManager = await ethers.getContractFactory("AccessManager");
        accessManager = await AccessManager.deploy(owner.address);
        await accessManager.grantAuthorizedContractRole(authorizedContract.address);

        Actor = await ethers.getContractFactory("Actor");
        actor = await Actor.deploy(accessManager.target, "TestActor", "TA");
        return actor;
    });

    describe("Deployment", function () {
        it("Should set the correct name and symbol", async function () {
            expect(await actor.name()).to.equal("TestActor");
            expect(await actor.symbol()).to.equal("TA");
        });
    });

    describe("Register Actor", function () {
        it("Should registerActor(), set token URI & return the Id", async function () {
            const actorId = 1;
            await actor.connect(authorizedContract).registerActor(account1.address, actorId, hash);
            expect(await actor.ownerOf(actorId)).to.equal(account1.address);
            expect(await actor.tokenURI(actorId)).to.equal(`ipfs://${hash}`);
        });

        it("Should revert when registering an already registered actor", async function () {
            const actorId = 1;
            await actor.connect(authorizedContract).registerActor(account1.address, actorId, hash);
            await expect(actor.connect(authorizedContract).registerActor(account1.address, actorId, hash))
                .to.be.revertedWithCustomError(actor, "DoubleRegistrationNotAllowed");
        });
    });

    describe("Update Actor", function () {
        it("Should update the actor's token URI", async function () {
            const tokenId = 1;
            await actor.connect(authorizedContract).registerActor(account1.address, tokenId, hash);
            await actor.connect(authorizedContract).updateActor(tokenId, newHash);
            expect(await actor.tokenURI(tokenId)).to.equal(`ipfs://${newHash}`);
        });
    });

    describe("ERC721 Overrides", function () {
        it("Should support the necessary interfaces", async function () {
            expect(await actor.supportsInterface("0x80ac58cd")).to.be.true; // ERC721
            expect(await actor.supportsInterface("0x5b5e139f")).to.be.true; // ERC721Metadata
            expect(await actor.supportsInterface("0x780e9d63")).to.be.true; // ERC721Enumerable
        });

        it("Should return the correct tokenURI", async function () {
            const tokenId = 1;
            await actor.connect(authorizedContract).registerActor(account1.address, tokenId, hash);
            expect(await actor.tokenURI(tokenId)).to.equal(`ipfs://${hash}`);
        });
    });

    describe("Soulbound Tokens", function () {
        it("Should revert on transferFrom()", async function () {
            const tokenId = 1;
            await actor.connect(authorizedContract).registerActor(account1.address, tokenId, "hash1");
            await expect(actor.connect(account1).transferFrom(account1.address, account2.address, tokenId))
                .to.be.revertedWithCustomError(actor, "SoulBoundTransferNotAllowed");
        });

        it("Should revert on safeTransferFrom()", async function () {
            const tokenId = 1;
            await actor.connect(authorizedContract).registerActor(account1.address, tokenId, "hash1");
            await expect(actor.connect(account1)["safeTransferFrom(address,address,uint256)"](account1.address, account2.address, tokenId))
                .to.be.revertedWithCustomError(actor, "SoulBoundTransferNotAllowed");
        });

        it("Should revert on safeTransferFrom(data)", async function () {
            const tokenId = 1;
            await actor.connect(authorizedContract).registerActor(account1.address, tokenId, "hash1");
            await expect(actor.connect(account1)["safeTransferFrom(address,address,uint256,bytes)"](account1.address, account2.address, tokenId, "0x"))
                .to.be.revertedWithCustomError(actor, "SoulBoundTransferNotAllowed");
        });
    });
});
