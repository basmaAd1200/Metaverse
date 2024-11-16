// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MetaMail {
    address public owner;
    Email generalMail;

    struct Email {
        address sender;
        address receiver;
        string subject;
        string content;
        uint256 timestamp;
    }

    Email[] private emails;
    mapping(address => uint256[]) private sentEmails;
    mapping(address => uint256[]) private receivedEmails;

    event EmailSent(uint256 indexed emailId, address indexed sender, address indexed receiver, string subject, string content);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    function sendEmail(address _receiver, string memory _subject, string memory _content) external {
        require(_receiver != msg.sender, "Sender cannot send email to themselves");
        require(_receiver != address(0), "Receiver address cannot be 0x0");
        require(bytes(_subject).length > 0, "Subject cannot be empty");
        require(bytes(_content).length > 0, "Content cannot be empty");
        
        uint256 emailId = emails.length;
        uint256 timestamp = block.timestamp; // Current block timestamp (UTC)
        emails.push(Email(msg.sender, _receiver, _subject, _content, timestamp));
        sentEmails[msg.sender].push(emailId);
        receivedEmails[_receiver].push(emailId);

        emit EmailSent(emailId, msg.sender, _receiver, _subject, _content);
    }



    function setGeneralMail(string memory _subject, string memory _content) external onlyOwner {
        generalMail = Email(owner, address(0), _subject, _content, block.timestamp);
    }

    function getSentEmails() external view returns (uint256[] memory _sentEmails) {
        return sentEmails[msg.sender];
    }

    function getReceivedEmails() external view returns (uint256[] memory _receivedEmails) {
        return receivedEmails[msg.sender];
    }

    function getEmailContent(uint256 _emailId) external view returns (address sender, string memory subject, string memory content, uint256 time) {
        require(_emailId < emails.length, "Email ID does not exist");
        Email memory email = emails[_emailId];
        require(msg.sender == email.sender || msg.sender == email.receiver, "You are not authorized to access this email");
        return (email.sender, email.subject, email.content, email.timestamp);
    }
    

    function getGeneralMail() external view returns (address sender, string memory subject, string memory content, uint256 time) {
        return (generalMail.sender, generalMail.subject, generalMail.content, generalMail.timestamp);
    }
}
