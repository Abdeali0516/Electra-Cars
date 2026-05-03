import { LightningElement, track } from 'lwc';
import logo from '@salesforce/resourceUrl/ElectraLogo';
export default class ElectraCarsHome extends LightningElement {

    @track form = {
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        enquiry: 'Customer Support',
        message: ''
    };

    @track formSuccess = false;
    logo = logo;
    stats = [
        { value: '300K+', label: 'Vehicles on Road' },
        { value: '500+',  label: 'Dealer Partners' },
        { value: '28',    label: 'States Covered' },
        { value: '8+',    label: 'Years in EV' },
        { value: '4.8★',  label: 'Customer Rating' }
    ];

    trustItems = [
        { icon: '🏭', text: 'Registered OEM — India Ministry of Road Transport' },
        { icon: '✅', text: 'ISO 9001:2015 Certified' },
        { icon: '🔒', text: 'FAME-II Scheme Participant' },
        { icon: '🌿', text: 'BEE 5-Star Rated EVs' },
        { icon: '📞', text: '24/7 Roadside Assistance' }
    ];

    values = [
        { icon: '⚡', text: 'Founded with the mission to make premium electric vehicles accessible across every Indian city and town, backed by a nationwide dealer network.' },
        { icon: '🔧', text: 'Our comprehensive warranty and after-sales program ensures every Electra owner has peace of mind — from purchase to the end of vehicle life.' },
        { icon: '🤝', text: 'We partner with 500+ authorised dealers across 28 states, providing training, tools, and digital support to deliver world-class service.' },
        { icon: '🌱', text: 'Each Electra vehicle offsets an average of 2.4 tonnes of CO₂ annually compared to an equivalent petrol car — contributing to India\'s net-zero targets.' }
    ];

    aboutCards = [
        {
            icon: '🏭',
            title: 'Manufacturing Excellence',
            desc: 'Our state-of-the-art production facility spans 120 acres with an annual capacity of 80,000 vehicles. Every car is built to AIS-048 and AIS-156 safety standards.'
        },
        {
            icon: '⚙️',
            title: 'Warranty Claim System',
            desc: 'Automotive Electra operates a fully digitalised warranty claims platform for our dealer network — enabling prior-authorisation requests, parts tracking, and faster repair turnaround times.'
        }
    ];

    vehicles = [
        {
            emoji: '🚗',
            model: 'Surge X',
            type: 'Premium Sedan',
            desc: 'Our flagship sedan combining luxury, technology and a 520 km real-world range. Ideal for executives and long-distance professionals.',
            specs: [
                { val: '520 km', key: 'Range' },
                { val: '75 kWh', key: 'Battery' },
                { val: '6.2s',   key: '0–100 kmph' }
            ]
        },
        {
            emoji: '🚙',
            model: 'Volt SUV',
            type: 'Electric SUV',
            desc: 'A family-first electric SUV built for highways and city alike. Features dual-motor AWD, panoramic roof and Level 2 ADAS.',
            specs: [
                { val: '460 km', key: 'Range' },
                { val: '82 kWh', key: 'Battery' },
                { val: '7 Seats', key: 'Capacity' }
            ]
        },
        {
            emoji: '🚐',
            model: 'Zap Compact',
            type: 'City Hatchback',
            desc: 'Affordable urban EV with a 280 km range, fast-charge capability, and the lowest total cost of ownership in its class.',
            specs: [
                { val: '280 km', key: 'Range' },
                { val: '38 kWh', key: 'Battery' },
                { val: '45 min', key: 'Fast Charge' }
            ]
        }
    ];

    services = [
        {
            icon: '🛡️',
            title: 'Comprehensive Warranty Programme',
            desc: 'All Electra vehicles come with 5-year / 1,50,000 km vehicle warranty, 8-year / 1,60,000 km battery warranty, and a 3-year electrical components warranty — one of the most extensive in India.'
        },
        {
            icon: '📱',
            title: 'Digital Warranty Claim Portal',
            desc: 'Our dealer network submits and tracks warranty claims via a Salesforce-powered digital system. Dealers can request prior-authorisation for spare parts directly through WhatsApp or our web portal — eliminating paper forms.'
        },
        {
            icon: '🔩',
            title: 'Genuine Spare Parts',
            desc: 'Electra Genuine Parts are available at all 500+ authorised service centres. Our parts logistics network ensures same-day availability in Tier 1 cities and 48-hour delivery to Tier 2 & 3 locations.'
        },
        {
            icon: '🚨',
            title: '24/7 Roadside Assistance',
            desc: 'Electra CARE is our round-the-clock roadside assistance programme covering towing, mobile charging, flat tyre help, and emergency technical support across all covered states.'
        },
        {
            icon: '🔋',
            title: 'Battery Health Monitoring',
            desc: 'Every Electra vehicle is equipped with cloud-connected Battery Management System (BMS). Our service team proactively monitors battery health and alerts owners and dealers before issues arise.'
        },
        {
            icon: '🎓',
            title: 'Electra Academy — Dealer Training',
            desc: 'We continuously train our dealer service teams on EV-specific diagnostics, high-voltage safety, and warranty claim procedures through our Electra Academy certification programme.'
        }
    ];

    dealerStats = [
        { value: '500+',  label: 'Authorised Dealers' },
        { value: '28',    label: 'States & UTs' },
        { value: '180+',  label: 'Service Centres' },
        { value: '<4 hr', label: 'Warranty Decision SLA' }
    ];

    contactItems = [
        {
            icon: '🏢',
            label: 'Registered Address',
            html: 'Automotive Electra India Pvt. Ltd.<br/>Ahmedabad, Gujarat – 380006'
        },
        {
            icon: '📞',
            label: 'Customer Care',
            html: '1800-123-4567 (Toll Free)<br/>Mon – Sat, 8:00 AM – 8:00 PM IST'
        },
        {
            icon: '✉️',
            label: 'Email',
            html: 'quintminds@gmail.com — Customer Support'
        },
        {
            icon: '💬',
            label: 'WhatsApp Business',
            html: '+91 75749 59453<br/>Warranty claim submissions & service queries'
        },
        {
            icon: '🌐',
            label: 'Online Presence',
            html: '<a href="https://orgfarm-b439876861.my.site.com/electraWarranty20" target="_blank">www.electracars.in</a>'
        }
    ];

    footerCols = [
        {
            heading: 'Company',
            links: [
                { label: 'About Us', href: '#about' },
                { label: 'Leadership Team', href: '#' },
                { label: 'Manufacturing', href: '#' },
                { label: 'Sustainability', href: '#' },
                { label: 'Careers', href: '#' },
                { label: 'News & Media', href: '#' }
            ]
        },
        {
            heading: 'Products',
            links: [
                { label: 'Surge X Sedan', href: '#vehicles' },
                { label: 'Volt SUV', href: '#vehicles' },
                { label: 'Zap Compact', href: '#vehicles' },
                { label: 'Accessories', href: '#' },
                { label: 'Home Chargers', href: '#' },
                { label: 'Fleet Solutions', href: '#' }
            ]
        },
        {
            heading: 'Support',
            links: [
                { label: 'Warranty', href: '#services' },
                { label: 'Service Centres', href: '#services' },
                { label: 'Find a Dealer', href: '#dealers' },
                { label: 'Spare Parts', href: '#' },
                { label: 'Owner Manual', href: '#' },
                { label: 'Contact Us', href: '#contact' }
            ]
        }
    ];

    handleNavClick(event) {
        event.preventDefault();
        const href = event.currentTarget.getAttribute('href');
        if (href && href.startsWith('#')) {
            const targetId = href.substring(1);
            const target = this.template.querySelector(`[id="${targetId}"]`);
            if (target) {
                target.scrollIntoView({ behavior: 'smooth' });
            }
        }
    }

    handleFormChange(event) {
        const field = event.target.dataset.field;
        this.form = { ...this.form, [field]: event.target.value };
    }

    handleSubmit() {
        const { firstName, lastName, email, message } = this.form;
        if (!firstName || !lastName || !email || !message) {
            // In a real implementation, show validation errors
            // Using console for LWC compatibility (no window.alert)
            console.warn('ElectraCarsHome: Please fill in all required fields.');
            return;
        }
        // In a real implementation you'd call an Apex method here:
        // submitEnquiry({ formData: this.form })
        //     .then(() => { this.formSuccess = true; })
        //     .catch(err => console.error(err));
        this.formSuccess = true;
        this.form = { firstName: '', lastName: '', email: '', phone: '', enquiry: 'Customer Support', message: '' };
    }

    connectedCallback() {
        // Intersection Observer for fade-in animations
        // LWC does not have direct DOM access until renderedCallback
    }

    renderedCallback() {
        // Lazy animation via IntersectionObserver (runs once)
        if (this._observerSetup) return;
        this._observerSetup = true;

        const observer = new IntersectionObserver(entries => {
            entries.forEach(e => {
                if (e.isIntersecting) {
                    e.target.classList.add('ec-visible');
                }
            });
        }, { threshold: 0.1 });

        this.template.querySelectorAll(
            '.ec-vehicle-card, .ec-service-card, .ec-about-card, .ec-dealer-stat-card'
        ).forEach(el => observer.observe(el));
    }
}